#!/bin/bash
#
# Attempts to clone down the test package and run it

# Save directory info
cd "$(dirname ${BASH_SOURCE[0]})"
workdir=$(pwd)

# Install dependencies
sudo yum install beakerlib python3-lxml

# Clone test
rhpkg --verbose --user=jenkins clone tests/rhel-system-roles
cd rhel-system-roles
git checkout private-upstream_testsuite_refactor
cd Sanity/Upstream-testsuite

# Define output
output_dir="$workdir/artifacts/rhel-system-roles/results"
output_file="$output_dir/$(arch)-test-output.txt"
mkdir -p $output_dir

# Run the test
sudo make &> $output_file run

# Ensure Success
grep "OVERALL RESULT" $output_file | grep "PASS"
