def call(List<String> remote_cmds=[]) {
  try {
    unstash('test.hostname')
    def test_hostname = readFile('test.hostname')
    echo "test_hostname: ${test_hostname}"
    for (cmd in remote_cmd) {
      withEnv(["test_hostname=${test_hostname}", "task=${task}"]) {
        sh('''#!/usr/bin/bash -xeu
              ssh_opts="-t -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -l root"
              ssh ${ssh_opts} ${test_hostname} "${cmd}"
           ''')
      }
    }
  }
  catch (err) {
    echo err.getMessage()
    throw err
  }
}