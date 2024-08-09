#!/usr/bin/bash

export GIT_SSH_COMMAND='ssh -o StrictHostKeyChecking=no'

# Update known_hosts (only for bitbucket once in a while)
#ssh-keygen -f "/root/.ssh/known_hosts" -R "bitbucket.org"
#ssh-keyscan -H bitbucket.org >> ~/.ssh/known_hosts

if [ -z $1 ]; then
  BRANCH="dev"
else
  BRANCH="$1"
fi

# Update EAMD
cd /var/dev
git clone 2cuBitbucket:donges/EAMD.ucp.git || true
cd EAMD.ucp
git reset --hard
git checkout $BRANCH
git pull

# Remove Once.2023 (obsolete after Jenkiins in green again)
cd /var/dev
rm -rf Once.2023
