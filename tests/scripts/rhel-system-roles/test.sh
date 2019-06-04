#!/bin/bash
#
# Attempts to clone down the test package and run it

# Save directory info
workdir="$(dirname $(readlink -f ${BASH_SOURCE[0]}))"
pushd $workdir

# Get OS information
. /etc/os-release
OS_MAJOR_VERSION=$(echo $VERSION_ID | cut -d '.' -f 1)

# Ensure test env is installed
# sudo yum install -y beakerlib rhts-test-env beah beakerlib-redhat

# Install brew for additional dependencies
sudo yum install -y koji brewkoji
brew download-build --rpm beakerlib-libraries-0.4-1.module+el8+2902+97ffd857.noarch.rpm
ls *.rpm && sudo yum --nogpgcheck localinstall -y *.rpm

# Configure pulp repos
PULP_BASEURL=http://pulp.dist.prod.ext.phx2.redhat.com/content/dist
declare -A RHEL7_SOURCEDIRS=( ["x86_64"]="server" ["ppc64le"]="power-le" ["aarch64"]="arm-64" ["s390x"]="system-z" )
ANSIBLE_VER="2"
RHEL7_ANSIBLE_REPO=$PULP_BASEURL/rhel/${RHEL7_SOURCEDIRS[$(arch)]}/$OS_MAJOR_VERSION/$OS_MAJOR_VERSION$VARIANT/$(arch)/ansible/$ANSIBLE_VER/os
RHEL8_ANSIBLE_REPO=$PULP_BASEURL/layered/rhel8/$(arch)/ansible/$ANSIBLE_VER/os
case "$OS_MAJOR_VERSION" in
    "7") ANSIBLE_REPO=$RHEL7_ANSIBLE_REPO;;
    "8") ANSIBLE_REPO=$RHEL8_ANSIBLE_REPO;;
esac

# Install pulp ansible repo and gpg key
sudo yum-config-manager --add-repo  $ANSIBLE_REPO
sudo rpm --import https://www.redhat.com/security/fd431d51.txt

# Install pulp extras repo on RHEL 7
if [ "$OS_MAJOR_VERSION" == "7" ]; then
    RHEL7_EXTRAS_REPO=$PULP_BASEURL/rhel/${RHEL7_SOURCEDIRS[$(arch)]}/$OS_MAJOR_VERSION/$OS_MAJOR_VERSION$VARIANT/$(arch)/extras/os
    sudo yum-config-manager --add-repo $RHEL7_EXTRAS_REPO
fi

# Install test dependencies
sudo yum install -y rhpkg yum-utils wget qemu-kvm genisoimage

# Install target ansible and rhel-system-roles
sudo yum install -y ansible rhel-system-roles

# Install libxml on rhel 8
if [ "$OS_MAJOR_VERSION" == "8" ]; then
    sudo yum install -y python3-lxml
fi

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

# Ensure Success and Restore Directory
grep "OVERALL RESULT" $output_file | grep "PASS" && popd
