#!/bin/bash

source .env

# Log verbose
function logVerbose() {
    # Check for verbosity not equal to -v
    if [ "$VERBOSITY" != "-v" ]; then
        return
    fi
    echo "$@"
}

# Log
function log() {
    if [ "$VERBOSITY" == "-s" ]; then
        return
    fi
    echo "$@"
}

# Banner
function banner() {
    logVerbose
    logVerbose "--- $1"
    logVerbose
}

function checkURL() {
    comment=$1
    shift
    logVerbose
    logVerbose call: curl -k -s -o /dev/null -w "%{http_code}" "$@"
    up=$(curl -k -s -o /dev/null -w "%{http_code}" "$@")
    if [[ "$up" != "200" && "$up" != "302" ]]; then
        log "$1 is not running (returned $up) - $comment"
        return 1
    else
        log "OK: running: $1 - $comment"
        return 0
    fi
}

function up() {
    # Create jenkins image
    banner "Create jenkins image"
    log "Building image..."
    if [ "$VERBOSITY" == "-v" ]; then
        docker build -t ${SCENARIO_DOCKER_IMAGENAME} .
    else
        docker build -t ${SCENARIO_DOCKER_IMAGENAME} . > /dev/null
    fi
    docker tag ${SCENARIO_DOCKER_IMAGENAME} ${SCENARIO_DOCKER_IMAGENAME}:${SCENARIO_DOCKER_IMAGEVERSION}
    docker tag ${SCENARIO_DOCKER_IMAGENAME} ${SCENARIO_DOCKER_IMAGENAME}:latest

    # Create and run container
    banner "Create and run container"
    docker-compose -p $SCENARIO_NAME up -d
    if [ "$VERBOSITY" == "-v" ]; then
        docker ps
    fi
}

function start() {
    # Start container
    banner "Start container"
    docker-compose -p $SCENARIO_NAME start
}

function stop() {
    # Stop container
    banner "Stop container"
    docker-compose -p $SCENARIO_NAME stop
    docker ps | grep $SCENARIO_NAME
}

function down() {
    # Shutdown and remove containers
    banner "Shutdown and remove containers"
    docker-compose -p $SCENARIO_NAME down
    if [ "$VERBOSITY" == "-v" ]; then
        docker ps
    fi

    # Cleanup docker
    banner "Cleanup docker"
    docker image rm ${SCENARIO_DOCKER_IMAGENAME}:${SCENARIO_DOCKER_IMAGEVERSION}
    docker image rm ${SCENARIO_DOCKER_IMAGENAME}:latest
    docker image prune -f

    # Test
    banner "Test"
    if [ "$VERBOSITY" == "-v" ]; then
        tree -L 3 -a .
    fi
}

function test() {
    # Print volumes, images, containers and files
    if [ "$VERBOSITY" = "-v" ]; then
        banner "Test"
        log "Volumes:"
        docker volume ls | grep jenkins_home
        log "Images:"
        docker image ls | grep $SCENARIO_DOCKER_IMAGENAME
        log "Containers:"
        docker ps -all | grep $SCENARIO_RESOURCE_CONTAINERNAME
        log "Files:"
        pwd
        tree -L 3 -a .
    fi

    # Check EAMD.ucp git status
    banner "Check Jenkins $SCENARIO_SERVER_NAME - $SCENARIO_NAME"
    checkURL "Jenkins (http)" http://$SCENARIO_SERVER_NAME:$SCENARIO_RESOURCE_HTTPPORT/jenkins
    return $? # Return the result of the last command
}

function printUsage() {
    log "Usage: $0 (up,start,stop,down,test)  [-v|-s|-h]"
    exit 1
}

# Scenario vars
if [ -z "$1" ]; then
    printUsage
fi

STEP=$1
shift

# Parse all "-" args
for i in "$@"
do
case $i in
    -v|--verbose)
    VERBOSITY=$i
    ;;
    -s|--silent)
    VERBOSITY=$i
    ;;
    -h|--help)
    HELP=true
    ;;
    *)
    # unknown option
    log "Unknown option: $i"
    printUsage
    ;;
esac
done

# Print help
if [ "$HELP" = true ]; then
    printUsage
fi

if [ $STEP = "up" ]; then
    up
elif [ $STEP = "start" ]; then
    start
elif [ $STEP = "stop" ]; then
    stop
elif [ $STEP = "down" ]; then
    down
elif [ $STEP = "test" ]; then
    test
else
    printUsage
    exit 1
fi

exit $?
