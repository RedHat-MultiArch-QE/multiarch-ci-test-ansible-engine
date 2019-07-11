#!/bin/bash
function test_success {
  set +x
  logfile=$1
  known_problems=$2
  status=0
  while read -u 3 -r line ; do
    accepted=1
    while read -u 4 -r acceptable_failure; do
        if [ ! -z $acceptable_failure ]; then
          echo $line | grep $acceptable_failure > /dev/null
          failure_is_acceptable=$?
          #echo '  >' $failure_is_acceptable

          [ $accepted -eq 0 ] || [ $failure_is_acceptable -eq 0 ]
          accepted=$?
        fi
    done 4< $known_problems
    [ $status -eq 0 ] && [ $accepted -eq 0 ] 
    status=$?
    #echo $status
  done 3< <(grep '\[   FAIL   \]' $logfile)
  final_status=$status
  #echo 'final status:' $final_status

  set -x
  return $status
}
