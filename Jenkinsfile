properties(
  [
    pipelineTriggers(
      [
        [
          $class: 'CIBuildTrigger',
          checks: [],
          overrides: [topic: "Consumer.rh-jenkins-ci-plugin.7b1f1e65-fc49-4d3c-be28-2a6528a814fc.VirtualTopic.eng.brew.>"],
          providerName: 'Red Hat UMB',
          selector: 'name = \'ansible\' AND type = \'Tag\' AND tag LIKE \'ansible-%-rhel-%-candidate\''
        ]
      ]
    ),
    parameters(
      [
        string(
          defaultValue: 'x86_64,ppc64le',
          description: 'A comma separated list of architectures to run the test on. Valid values include [x86_64, ppc64le, aarch64, s390x].',
          name: 'ARCHES'
        ),
        string(
          defaultValue: 'https://github.com/jaypoulz/multiarch-ci-libraries',
          description: 'Repo for shared libraries.',
          name: 'LIBRARIES_REPO'
        ),
        string(
          defaultValue: 'dev-v1.2.0',
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
          defaultValue: 'jpoulin',
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

List arches = params.ARCHES.tokenize(',')
def errorMessages = ''
def config = MAQEAPI.v1.getProvisioningConfig(this)
config.installRhpkg = true

println(config.runOnSlave)
println(config.mode)

MAQEAPI.v1.runParallelMultiArchTest(
  this,
  arches,
  config,
  { host ->
    /*********************************************************/
    /* TEST BODY                                             */
    /* @param host               Provisioned host details.   */
    /*********************************************************/
    installBrewPkgs(params)

    stage ('Download Test Files') {
      downloadTests()
    }

    stage ('Run Test') {
      runTests(config, host)
    }

    stage ('Archive Test Output') {
      archiveOutput()
    }

    /*****************************************************************/
    /* END TEST BODY                                                 */
    /* Do not edit beyond this point                                 */
    /*****************************************************************/
  },
  { Exception exception, def host ->
    def error = "Exception ${exception} occured on ${host.arch}\n"
    errorMessages += error
    if (host.arch.equals("x86_64") || host.arch.equals("ppc64le")) {
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

    def emailBody = "Results for ${env.JOB_NAME} - Build #${currentBuild.number}\n\nResult: ${currentBuild.currentResult}\nURL: $BUILD_URL"
    if (errorMessages) emailBody += "\nErrors: " + errorMessages
 
    emailext(
      subject: "${env.JOB_NAME} - Build #${currentBuild.number} - ${currentBuild.currentResult}",
      body: emailBody,
      from: 'multiarch-qe-jenkins',
      replyTo: 'multiarch-qe',
      to: "${params.EMAIL_SUBSCRIBERS}",
      attachmentsPattern: 'artifacts/tests/scripts/rhel-system-roles/artifacts/**/*.*'
    )
  }
)
