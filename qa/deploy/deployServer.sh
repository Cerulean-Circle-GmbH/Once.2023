#!/bin/bash

# Get current dir
pushd $(dirname $0) > /dev/null
cwd=$(pwd)
popd > /dev/null

function callRemote() {
    ssh $SCENARIO_SERVER bash -s << EOF
cd $SCENARIOS_DIR_REMOTE/$SCENARIO_NAME
$@
EOF
}

function banner() {
    echo
    echo "####################################################################################################"
    echo "## $@"
    echo "####################################################################################################"
    echo
}

function checkURL() {
    up=$(curl -s -o /dev/null -w "%{http_code}" $1)
    if [ "$up" != "200" ]; then
        echo "ERROR: $1 is not running (returned $up)"
    else
        echo "OK: $1 is running"
    fi
}

# Scenario vars
SCENARIO_NAME=dev
source .env.$SCENARIO_NAME

# Cleanup remotely
banner "Cleanup remotely"
callRemote ./scenario.cleanup.sh || true

# Init locally and sync remote
./local.scenario.init.sh $SCENARIO_NAME

# Startup WODA with WODA.2023 container and check that startup is done
banner "Startup WODA with WODA.2023 container and check that startup is done"
callRemote ./scenario.install.sh

# Restart once server
banner "Restart once server"
callRemote ./scenario.start.sh

# Check running servers
./local.scenario.test.sh $SCENARIO_NAME

# /var/dev/EAMD.ucp/Components/com/ceruleanCircle/EAM/1_infrastructure/NewUserStuff/scripts/structr.initApps