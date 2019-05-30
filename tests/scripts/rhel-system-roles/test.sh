#!/bin/bash
#
# Attempts to clone down the test package and run it

# Save directory info
cd "$(dirname ${BASH_SOURCE[0]})"
workdir=$(pwd)

# Install dependencies
. /etc/os-release
OS_MAJOR_VERSION=$(echo $VERSION_ID | cut -d '.' -f 1)
if [ "$OS_MAJOR_VERSION" == "8" ]; then
    sudo yum install beakerlib python3-lxml koji brewkoji -y
fi

brew download-build --rpm beakerlib-libraries-0.4-1.module+el8+2902+97ffd857.noarch.rpm
ls *.rpm && sudo yum --nogpgcheck localinstall -y *.rpm
sudo yum install -y ansible rhpkg yum-utils wget qemu-kvm genisoimage rhel-system-roles

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
