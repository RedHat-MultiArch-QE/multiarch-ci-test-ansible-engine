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
            overrides: [topic: 'Consumer.rh-jenkins-ci-plugin.362b4d33-54cc-4d94-84af-ad1732e30928.VirtualTopic.eng.brew.>'],
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
          defaultValue: 'https://github.com/jaypoulz/multiarch-ci-libraries',
          description: 'Repo for shared libraries.',
          name: 'LIBRARIES_REPO'
        ),
        string(
          defaultValue: 'dev-v2.0.0',
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
          defaultValue: '18574111',
          description: 'Build task ID for which to run the pipeline',
          name: 'TASK_ID'
        ),
        string(
          defaultValue: 'RHEL-7.6',
          description: 'RHEL 7 distribution.',
          name: 'RHEL7_DISTRO'
        ),
        string(
          defaultValue: 'RHEL-8.0.0',
          description: 'RHEL 8 distribution.',
          name: 'RHEL8_DISTRO'
        ),
        string(
          defaultValue: 'jpoulin', //; mclay; djez; pcahyna',
          description: 'Semi-colon delimited list of email notification recipients.',
          name: 'EMAIL_SUBSCRIBERS'
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

// MACIT configuration
def errorMessages = ''
def config = MAQEAPI.v1.getProvisioningConfig(this)
config.installRhpkg = true
config.jobgroup = 'multiarch-qe'
config.teardown = true

// Job Configuration
def useDebugServer = false

// Get build information
Map message = [:]
String taskId = ''
String nvr = ''

// Required host information
List arches = []
String os = ''
String distro = ''
String variant = ''

final Map<String,List<String>> SUPPORTED_ARCHES = [
    'rhel-7': [X86_64, PPC64LE],
    'rhel-8': [X86_64, PPC64LE, AARCH64, S390X]
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
    if (!os || !(['rhel-7', 'rhel-8'].contains(os))) {
      error("Invalid OS version: ${os}.")
    }

    // Distro
    distro = (os == 'rhel-8') ? params.RHEL8_DISTRO : params.RHEL7_DISTRO
    if (!distro) {
      error("Invalid distro: ${distro}.")
    }

    // Ensure arch is supported for 
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
    

    // Variant
    variant = (os == 'rhel-8') ? 'BaseOS' : 'Server'
    if (!variant) {
      error("Invalid variant: ${variant}.")
    }
  }
}

def targetHosts = []
for (String arch in arches) {
  def targetHost = MAQEAPI.v1.newTargetHost()
  targetHost.arch = arch
  targetHost.distro = distro
  targetHost.variant = variant
  if (os == 'rhel-8') {
      targetHost.inventoryVars = [ ansible_python_interpreter:'/usr/libexec/platform-python' ]
  }

  // Ensure there is enough memory to run KVM
  targetHost.bkrHostRequires = [[ tag: 'memory', op: '>=', value: '2048', type:'system' ]]

  // Ensure x86_64 hosts support virtualization
  if (targetHost.arch == X86_64) {
      targetHost.bkrKeyValue = [ 'HVM==1' ]

      // Use testing box
      if (useDebugServer) {
          targetHost.hostname = 'jpoulin-02.usersys.redhat.com'
          targetHost.provisioner = 'NOOP'
      }
  }

  // Ensure power machine is baremetal or running powerVM
  if (targetHost.arch == PPC64LE) {
      targetHost.bkrHostRequires.add([ rawxml: '<system><or><hypervisor op="==" value=""/><hypervisor op="==" value="PowerVM"/></or></system>' ])
      
      // Disable radix on power because KVM will not work with PR type acceleration on Power 9 and PowerVM LPARs do not support HV
      targetHost.bkrKernelOptionsPost = 'disable_radix'
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
    if (host.arch.equals(X86_64) || host.arch.equals(PPC64LE)) {
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
      to: "${params.EMAIL_SUBSCRIBERS}",
      attachmentsPattern: 'artifacts/tests/scripts/rhel-system-roles/artifacts/**/*.*'
    )
  }
)
