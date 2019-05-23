#!/bin/bash
#
# Attempts to clone down the test package and run it

cd "$(dirname ${BASH_SOURCE[0]})"
workdir=$(pwd)
rhpkg --verbose --user=jenkins clone tests/rhel-system-roles
cd rhel-system-roles
git checkout private-upstream_testsuite_refactor
cd Sanity/Upstream-testsuite
output_dir="$workdir/artifacts/rhel-system-roles/results"
output_file="$output_dir/$(arch)-test-output.txt"
mkdir -p $output_dir
sudo make &> $output_file run
grep "OVERALL RESULT" $output_file | grep "PASS"
