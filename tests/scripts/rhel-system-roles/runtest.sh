#!/bin/bash
# vim: dict+=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of /Ansible-Engine/Multiarch-testsuite
#   Description: Test executes upstream testsuite
#   Author: Jeremy Poulin <jpoulin@redhat.com>
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Copyright (c) 2017 Red Hat, Inc.
#
#   This program is free software: you can redistribute it and/or
#   modify it under the terms of the GNU General Public License as
#   published by the Free Software Foundation, either version 2 of
#   the License, or (at your option) any later version.
#
#   This program is distributed in the hope that it will be
#   useful, but WITHOUT ANY WARRANTY; without even the implied
#   warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR
#   PURPOSE.  See the GNU General Public License for more details.
#
#   You should have received a copy of the GNU General Public License
#   along with this program. If not, see http://www.gnu.org/licenses/.
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

# Include Beaker environment
. /usr/bin/rhts-environment.sh || exit 1
. /usr/share/beakerlib/beakerlib.sh || exit 1

PACKAGES="rhel-system-roles"
REQUIRES="ansible"
ROLES_PATH="/usr/share/ansible/roles"

function install_ansible()
{
    if rlIsRHEL ">7"; then
        echo "
[ansible-$1]
name=ansible-$1
baseurl=http://download.eng.rdu2.redhat.com/rhel-8/nightly/ANSIBLE/latest-ANSIBLE-$1-RHEL-8/compose/Base/$(arch)/os/
enabled=1
gpgcheck=0
" > /etc/yum.repos.d/ansible.repo
    else
        echo "
[ansible-$1]
name=ansible-$1
baseurl=http://pulp.dist.prod.ext.phx2.redhat.com/content/dist/rhel/server/7/7Server/$(arch)/ansible/$1/os/
enabled=1
gpgcheck=0
" > /etc/yum.repos.d/ansible.repo
    fi

    rlRun "yum -y install ansible"
    rlAssertRpm "ansible"
}

rlJournalStart
    rlPhaseStartSetup "Install rhel-system-roles"
        rlRun "rlImport 'distribution/extras'"
        rlRun "rlImport 'distribution/epel'"
        rlRun "rlImport 'distribution/RpmSnapshot'"
        rlRun "RpmSnapshotCreate"
        epelEnableMainRepo
        extrasEnableMainRepo
        extrasDisableMainRepo
        epelDisableMainRepo
    rlPhaseEnd

    rlPhaseStartSetup "Prepare upstream testsuite"
        rlFileBackup --clean --missing-ok /etc/yum.repos.d/ansible.repo
        mkdir -p /usr/share/ansible/inventory
        cp inventory /usr/share/ansible/inventory/target
        if [ -n "$ANSIBLE_VER" ]; then
            install_ansible $ANSIBLE_VER
        else
            rlLogInfo "ANSIBLE_VER not defined - using system ansible if installed"
        fi
        rlAssertRpm --all
        rlRun "TmpDir=\$(mktemp -d)" 0 "Creating tmp directory"
        rlRun "pushd $TmpDir"
    rlPhaseEnd

    rlPhaseStartTest
        ANSIBLE_VER=$(ansible --version | head -1 | cut -f 2 -d ' ')
        rlLog "Using Ansible-$ANSIBLE_VER"
        # iterate over each test yaml file
        for PLAYBOOK in $ROLES_PATH/rhel-system-roles.*/tests/tests_*.yml
        do
            testname=${PLAYBOOK#$ROLES_PATH/rhel-system-roles.}
            testname=${testname/\/tests/}
            LOGFILE="SYSTEM-ROLE-${testname//\//_}-ANSIBLE-$ANSIBLE_VER.log"
            # Allow space separated patterns to select only some tests, examples:
            # SYSTEM_ROLES_ONLY_TESTS=network/ -> Test only network role
            # SYSTEM_ROLES_ONLY_TESTS=network/tests_bridge.yml -> Run only tests_bridge.yml from network role
            if echo "${testname}" | egrep -qe "$(echo "${SYSTEM_ROLES_ONLY_TESTS}" | tr " " "|")"
            then
                rlRun "ansible-playbook -vvv -i /usr/share/ansible/inventory/target -l target_node $PLAYBOOK &> $LOGFILE" 0 "Test $testname ($PLAYBOOK) with ANSIBLE-$ANSIBLE_VER"
                rlFileSubmit "$LOGFILE"
            fi
        done
    rlPhaseEnd

    rlPhaseStartCleanup
        rlRun "RpmSnapshotRevert"
        rlRun "RpmSnapshotDiscard"
        rlRun "popd"
        rlRun "rm -r $TmpDir" 0 "Removing tmp directory"
        rlFileRestore
    rlPhaseEnd
rlJournalPrintText
rlJournalEnd
