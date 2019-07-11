properties(
  [
    pipelineTriggers(
      [
        [
          $class: 'CIBuildTrigger',
          noSquash: true,
          providerData:
            [
            $class: 'ActiveMQSubscriberProviderData',
            name: 'Red Hat UMB',
            overrides: [topic: 'Consumer.rh-jenkins-ci-plugin.20a11492-54d6-4843-8894-24bd09c30048.VirtualTopic.eng.brew.>'],
            selector: 'name = \'ansible\' AND type = \'Tag\' AND tag LIKE \'ansible-%-rhel-%-candidate\'',
            timeout: null
          ]
        ]
      ]
    ),
    parameters(
      [
        [$class: 'ValidatingStringParameterDefinition',
         defaultValue: 'all',
         description: 'A comma separated list of architectures to run the test on. Valid values include [all] for all supported arches, [x86_64, ppc64le] for RHEL-7, and [x86_64, ppc64le, aarch64, s390x] for RHEL-8.',
         failedValidationMessage: 'Invalid architecture. Valid values are [x86_64, ppc64le, aarch64, s390x].',
         name: 'ARCHES',
         regex: '^((all){1}|(?:x86_64|ppc64le|aarch64|s390x)(?:,\\s*(?:x86_64|ppc64le|aarch64|s390x))*)$'
        ],
        string(
          defaultValue: 'https://github.com/redhat-multiarch-qe/multiarch-ci-libraries',
          description: 'Repo for shared libraries.',
          name: 'LIBRARIES_REPO'
        ),
        string(
          defaultValue: 'v1.3.0',
          description: 'Git reference to the branch or tag of shared libraries.',
          name: 'LIBRARIES_REF'
        ),
        string(
          defaultValue: '',
          description: 'Repo for tests to run. If left blank, the current repo is assumed (*note* this default will only work for multibranch pipelines).',
          name: 'TEST_REPO'
        ),
        string(
          defaultValue: '',
          description: 'Git reference to the branch or tag of the tests repo.',
          name: 'TEST_REF'
        ),
        string(
          defaultValue: 'tests',
          description: 'Directory containing tests to run. Should at least one of the follow: an ansible-playbooks directory containing one or more test directories each of which having a playbook.yml, a scripts directory containing one or more test directories each of which having a run-test.sh',
          name: 'TEST_DIR'
        ),
        string(
          defaultValue: '',
          description: 'Contains the CI_MESSAGE for a message bus triggered build.',
          name: 'CI_MESSAGE'
        ),
        string(
          defaultValue: '21729319',
          description: 'Build task ID for which to run the pipeline',
          name: 'TASK_ID'
        ),
        string(
          defaultValue: 'RHEL-ALT-7.6',
          description: 'RHEL 7 distribution.',
          name: 'RHEL7_DISTRO'
        ),
        string(
          defaultValue: 'RHEL-8.0.0',
          description: 'RHEL 8 distribution.',
          name: 'RHEL8_DISTRO'
        ),
        string(
          defaultValue: 'rhel-system-roles-1.0-8.el7.noarch.rpm',
          description: 'Optional override to get the rhel-system-roles package from brew for RHEL 7.',
          name: 'RHEL7_SYSTEM_ROLES_OVERRIDE'
        ),
        string(
          defaultValue: 'rhel-system-roles-1.0-7.el8.noarch.rpm',
          description: 'Optional override to get the rhel-system-roles package from brew for RHEL 8.',
          name: 'RHEL8_SYSTEM_ROLES_OVERRIDE'
        ),
        [$class: 'ValidatingStringParameterDefinition',
         defaultValue: 'Upstream-testsuite',
         description: 'Parameter describing which of the system-roles tests to run on RHEL 7. Valid values are=["basic-smoke-test", "Upstream-testsuite", "Multiarch-testsuite"]',
         failedValidationMessage: 'Invalid test name. Valid values are ["basic-smoke-test", "Upstream-testsuite", "Multiarch-testsuite"].',
         name: 'RHEL7_TEST_TYPE',
         regex: '^(basic-smoke-test|Upstream-testsuite|Multiarch-testsuite){1}$'
        ],
        [$class: 'ValidatingStringParameterDefinition',
         defaultValue: 'basic-smoke-test',
         description: 'Parameter describing which of the system-roles tests to run on RHEL 8. Valid values are=["basic-smoke-test", "Upstream-testsuite", "Multiarch-testsuite"]',
         failedValidationMessage: 'Invalid test name. Valid values are ["basic-smoke-test", "Upstream-testsuite", "Multiarch-testsuite"].',
         name: 'RHEL8_TEST_TYPE',
         regex: '^(basic-smoke-test|Upstream-testsuite|Multiarch-testsuite){1}$'
        ],
        string(
          defaultValue: 'jpoulin; mclay; djez; pcahyna',
          description: 'Semi-colon delimited list of email notification recipients.',
          name: 'RHEL7_EMAIL_SUBSCRIBERS'
        ),
        string(
          defaultValue: 'jpoulin; mclay; djez; pcahyna',
          description: 'Semi-colon delimited list of email notification recipients.',
          name: 'RHEL8_EMAIL_SUBSCRIBERS'
        ),
        booleanParam(
          defaultValue: true,
          description: 'Force a ppc64le build to request a baremetal system.',
          name: 'FORCE_BAREMETAL_POWER_SYSTEM'
        ),
        booleanParam(
          defaultValue: true,
          description: 'Teardown on complete.',
          name: 'TEARDOWN'
        )
      ]
    )
  ]
)

library(
  changelog: false,
  identifier: "multiarch-ci-libraries@${params.LIBRARIES_REF}",
  retriever: modernSCM([$class: 'GitSCMSource',remote: "${params.LIBRARIES_REPO}"])
)

// String Constants
X86_64 = 'x86_64'
PPC64LE = 'ppc64le'
AARCH64 = 'aarch64'
S390X = 's390x'
RHEL7 = 'rhel-7'
RHEL8 = 'rhel-8'
UPSTREAM_TESTSUITE = 'Upstream-testsuite'
MULTIARCH_TESTSUITE = 'Multiarch-testsuite'
BASIC_SMOKE_TEST = 'basic-smoke-test'

// MACIT configuration
def errorMessages = ''
def config = MAQEAPI.v1.getProvisioningConfig(this)
config.installRhpkg = true
config.jobgroup = 'multiarch-qe'
config.teardown = params.TEARDOWN

// Get build information
Map message = [:]
String taskId = ''
String nvr = ''

// Required host information
List arches = []
String os = ''
String distro = ''
String variant = ''

// Selected parameter set
String systemRolesOverride = ''
String testType = ''
String emailSubscribers = ''

final Map<String,List<String>> SUPPORTED_ARCHES = [
  (RHEL7): [X86_64, PPC64LE],
  (RHEL8): [X86_64, PPC64LE, AARCH64, S390X]
]

// Lookup the build information
MAQEAPI.v1.testWrapper(this, config) {
  node ("provisioner-${config.version}"){
    // Message
    message = getCIMessage(params.CI_MESSAGE)

    // Task ID
    taskId = message && message.build && message.build.task_id ?: params.TASK_ID
    if (!taskId) {
      error("Invalid brew task ID for CI_MESSAGE: ${params.CI_MESSAGE} and TASK_ID: ${params.TASK_ID}.")
    }

    // NVR
    nvr = sh(script:"brew taskinfo ${taskId} | grep 'Build:' | cut -d' ' -f2", returnStdout:true)
    if (!nvr) {
      error("Invalid nvr: ${nvr}.")
    }

    // OS
    os = sh(
      script: """
        brew buildinfo \
            \$(brew taskinfo ${taskId} | grep 'Build:' | cut -d '(' -f 2 | cut -d ')' -f 1) | \
            grep 'Volume:' | cut -d ' ' -f 2
      """,
      returnStdout: true
    ).trim()
    if (!os || !([RHEL7, RHEL8].contains(os))) {
      error("Invalid OS version: ${os}.")
    }

    // Ensure arch is supported for os
    if (params.ARCHES == 'all') {
      arches = SUPPORTED_ARCHES[os]
    } else {
      arches = params.ARCHES.tokenize(',')
      for (arch in arches) {
        arch = arch.trim()
        if (!SUPPORTED_ARCHES[os].contains(arch)) {
          error("Invalid arch specification. Architecture $arch is not supported on $os")
        }
      }
    }
  }
}

// Select parameter set based on OS
if (os == RHEL8) {
  distro = params.RHEL8_DISTRO
  variant = 'BaseOS'
  systemRolesOverride = params.RHEL8_SYSTEM_ROLES_OVERRIDE
  testType = params.RHEL8_TEST_TYPE
  emailSubscribers = params.RHEL8_EMAIL_SUBSCRIBERS
} else {
  distro = params.RHEL7_DISTRO
  variant = 'Server'
  systemRolesOverride = params.RHEL7_SYSTEM_ROLES_OVERRIDE
  testType = params.RHEL7_TEST_TYPE
  emailSubscribers = params.RHEL7_EMAIL_SUBSCRIBERS
}

// Ensure distro cannot be null
if (!distro) {
   error("Distro for selected os ($os) cannot be null.")
}

// Ensure workspace is grabbed from test repo when we need beaker multi-resource
if (testType == MULTIARCH_TESTSUITE) {
  config.provisioningRepoUrl = null
}

def targetHosts = []
for (String arch in arches) {
  def targetHost = MAQEAPI.v1.newTargetHost()
  targetHost.name = arch
  targetHost.arch = arch
  targetHost.distro = distro
  targetHost.variant = variant
  targetHost.scriptParams = "$testType $systemRolesOverride"
  targetHost.inventoryVars = [
    ansible_ssh_private_key_file:'/home/jenkins/.ssh/id_rsa',
    ansible_ssh_common_args:'"-o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no"',
  ]
  if (os == RHEL8) {
    targetHost.inventoryVars << [ ansible_python_interpreter:'/usr/libexec/platform-python' ]
  }

  if (testType == UPSTREAM_TESTSUITE) {
    // Ensure there is enough memory to run KVM
    targetHost.bkrHostRequires = [[ tag: 'memory', op: '>=', value: '8192', type:'system' ]]

    // Ensure x86_64 hosts support virtualization
    if (targetHost.arch == X86_64) {
      targetHost.bkrKeyValue = [ 'HVM==1' ]
    }

    // Ensure power machine is baremetal or running powerVM
    if (targetHost.arch == PPC64LE) {
      if (params.FORCE_BAREMETAL_POWER_SYSTEM) {
        targetHost.bkrHostRequires.add([tag:'hypervisor', op:'==', value:''])
      } else {
        targetHost.bkrHostRequires.add([ rawxml: '<system><or><hypervisor op="==" value=""/><hypervisor op="==" value="PowerVM"/></or></system>' ])

        // Disable radix on power because KVM will not work with PR type acceleration on Power 9 and PowerVM LPARs do not support HV
        targetHost.bkrKernelOptionsPost = 'disable_radix'
      }
    }
  }

  targetHosts.push(targetHost)
}

MAQEAPI.v1.runTest(
  this,
  targetHosts,
  config,
  { host ->
    /*********************************************************/
    /* TEST BODY                                             */
    /* @param host               Provisioned host details.   */
    /*********************************************************/
    installBrewPkgs(params, config.runOnSlave, config, host)

    stage ('Download Test Files') {
      downloadTests()
    }

    stage ('Run Test') {
      runTests(config, host)
    }

    /*****************************************************************/
    /* END TEST BODY                                                 */
    /* Do not edit beyond this point                                 */
    /*****************************************************************/
  },
  { Exception exception, def host ->
    def error = "Exception ${exception} occured on ${host.arch}\n"
    errorMessages += error
    if (exception.message.contains('script returned exit code')) {
      currentBuild.result = 'UNSTABLE'
    } else {
      currentBuild.result = 'FAILURE'
    }
  },
  {
    try {
      sh "mkdir -p artifacts"
      unarchive(mapping: ['**/*.*' : 'artifacts/.'])
    } catch (e) {
      errorMessages += "Exception ${e} occured while unarchiving artifacts\n"
    }

    def emailBody = "Results for ${env.JOB_NAME} - Build #${currentBuild.number}\n\nResult: ${currentBuild.currentResult}\nNVR: ${nvr}\nURL: $BUILD_URL"
    if (errorMessages) emailBody += "\nErrors: " + errorMessages

    emailext(
      subject: "${nvr ? nvr + ' - ': ''}${currentBuild.currentResult} - ${env.JOB_NAME} (#${currentBuild.number})",
      body: emailBody,
      from: 'multiarch-qe-jenkins',
      replyTo: 'multiarch-qe',
      to: "$emailSubscribers",
      attachmentsPattern: 'artifacts/tests/scripts/rhel-system-roles/artifacts/**/*.*'
    )
  }
)
