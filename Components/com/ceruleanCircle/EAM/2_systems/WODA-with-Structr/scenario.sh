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
    if [ "$up" != "200" ]; then
        log "NO: $1 is not running (returned $up) - $comment"
        return 1
    else
        log "OK: running: $1 - $comment"
        return 0
    fi
}

function addToFile() {
    local file=$1
    local content=$2
    if [ -f "$file" ]; then
        cat $file | grep -v "$content" > $file.tmp
        cat $file.tmp > $file
        rm $file.tmp
        # Add content to file with using $content as variable
        echo "${content}=${!content}" >> $file
        logVerbose "Added $content to $file"
    fi
}

function calculateVolumeName() {
    if [[ -n "$SCENARIO_RESOURCE_ONCE_VOLUME" && "$SCENARIO_RESOURCE_ONCE_VOLUME" != "none" ]]; then
        SCENARIO_ONCE_VOLUME_NAME=$SCENARIO_RESOURCE_ONCE_SRCPATH
    elif [[ -n "$SCENARIO_RESOURCE_ONCE_SRCPATH"  && "$SCENARIO_RESOURCE_ONCE_SRCPATH" != "none" ]]; then
        SCENARIO_ONCE_VOLUME_NAME=$SCENARIO_RESOURCE_ONCE_SRCPATH
        # If SCENARIO_ONCE_VOLUME_NAME doesn't start with "/" or "." add a "./"
        if [[ ! "$SCENARIO_ONCE_VOLUME_NAME" =~ ^/ && ! "$SCENARIO_ONCE_VOLUME_NAME" =~ ^"." ]]; then
            SCENARIO_ONCE_VOLUME_NAME="./$SCENARIO_ONCE_VOLUME_NAME"
        fi
    else
        SCENARIO_ONCE_VOLUME_NAME=var_dev
    fi
    echo $SCENARIO_ONCE_VOLUME_NAME
}

function up() {
    mkdir -p structr/_data
    pushd structr/_data > /dev/null

    local certdir=$SCENARIO_SERVER_CERTIFICATEDIR

    # Handle volume
    SCENARIO_ONCE_VOLUME_NAME=$(calculateVolumeName)
    addToFile $SCENARIO_SERVER_CONFIGSDIR/$SCENARIO_NAME_SPACE/$SCENARIO_NAME/.env SCENARIO_ONCE_VOLUME_NAME

    # Keystore
    banner "Keystore"
    if [ -f "keystore.pkcs12" ]; then
        logVerbose "Already existing keystore.pkcs12..."
    else
        logVerbose "Creating new keystore.pkcs12..."
        if [ -n "$certdir" ] && [ -f "$certdir/fullchain.pem" ] && [ -f "$certdir/privkey.pem" ]; then
            echo "Using certificates from $certdir"
            ls -l $certdir > $VERBOSEPIPE
            ln -s $certdir/fullchain.pem fullchain.pem
            ln -s $certdir/privkey.pem privkey.pem
            openssl x509 -noout -fingerprint -sha256 -inform pem -in fullchain.pem > $VERBOSEPIPE 
            openssl x509 -noout -fingerprint -sha1 -inform pem -in fullchain.pem > $VERBOSEPIPE
            openssl x509 -noout -text -inform pem -in fullchain.pem  > $VERBOSEPIPE
        else
            # TODO: Check whether mkcert is installed and create certificates instead of copying
            #mkcert -cert-file fullchain.pem -key-file privkey.pem server.localhost localhost 127.0.0.1 ::1
            logVerbose "Linking commited fullchain.pem and privkey.pem..."
            ln -s ../../certbot/fullchain.pem fullchain.pem
            ln -s ../../certbot/privkey.pem privkey.pem
        fi
        openssl pkcs12 -export -out keystore.pkcs12 -in fullchain.pem -inkey privkey.pem -password pass:qazwsx#123 > $VERBOSEPIPE
    fi

    # Workspace
    banner "Workspace ($SCENARIO_SRC_STRUCTR_STRUCTRDATAFILE)"
    if [ -d "WODA-current" ]; then
        logVerbose "Already existing workspace..."
    else
        logVerbose "Fetching workspace..."
        RSYNC_VERBOSE="-q"
        if [ "$VERBOSITY" == "-v" ]; then
            RSYNC_VERBOSE="-v"
        fi
        rsync -azP $RSYNC_VERBOSE -L -e "ssh -o StrictHostKeyChecking=no" $SCENARIO_SRC_STRUCTR_STRUCTRDATAFILE WODA-current.tar.gz
        tar xzf WODA-current.tar.gz > $VERBOSEPIPE
    fi

    # structr.zip
    banner "structr.zip"
    if [ -f "structr.zip" ]; then
        logVerbose "Already existing structr.zip..."
    else
        logVerbose "Fetching structr.zip..."
        curl https://test.wo-da.de/EAMD.ucp/Components/org/structr/StructrServer/2.1.4/dist/structr.zip -o ./structr.zip > $VERBOSEPIPE
    fi

    popd > /dev/null

    # Create structr image
    banner "Create structr image"
    log "Building image..."
    docker-compose build > $VERBOSEPIPE
    docker image ls > $VERBOSEPIPE

    # Handle outer config only when localhost
    #SCENARIO_SRC_ONCE_OUTERCONFIG
    # Create .gitconfig
    #if [ ! -f $DOCKER_OUTER_CONFIG/.gitconfig ]; then
    #    mkdir -p $DOCKER_OUTER_CONFIG
    #    NAME=$(ask_with_default "Your full name  (for Git) :" "")
    #    MAIL=$(ask_with_default "Your full email (for Git) :" "")
    #    cat ../gitconfig.template | sed "s;##NAME##;$NAME;" | sed "s;##MAIL##;$MAIL;" > $DOCKER_OUTER_CONFIG/.gitconfig
    #fi

    # Create ssh keys
    #if [ ! -f $DOCKER_OUTER_CONFIG/.ssh/id_rsa ]; then
    #    mkdir -p $DOCKER_OUTER_CONFIG/.ssh
    #    ssh-keygen -f $DOCKER_OUTER_CONFIG/.ssh/id_rsa
    #fi

    # Create and run container
    banner "Create and run container"
    docker-compose -p $SCENARIO_NAME up -d
    if [ "$VERBOSITY" == "-v" ]; then
        docker ps
    fi

    # Wait for startup of container and installation of ONCE
    banner "Wait for startup of container and installation of ONCE"
    local found=""
    log "Wait for startup of container..."
    log
    log
    log
    log
    log
    log
    while [ -z "$found" ]; do
        local UP='\033[7A'
        local LINEFEED='\033[0G'
        local STR=$(docker logs -n 5 $SCENARIO_ONCE_CONTAINER 2>&1)
        log -e "$LINEFEED$UP"
        log "== Wait for startup... ==========================================================="
        if [ "$VERBOSITY" != "-s" ]; then
            while IFS= read -r line
            do
                local COLUMNS=80
                printf "\e[2m%-${COLUMNS}s\e[0m\n" "${line:0:${COLUMNS}}"
            done < <(printf '%s\n' "$STR")
        fi
        sleep 0.3
        found=$(docker logs $SCENARIO_ONCE_CONTAINER 2>/dev/null | grep "Welcome to Web 4.0")
    done
    logVerbose "===================="
    log "Startup done ($found)"

    # TODO: Mount directory into container and let ONCE use it
    
    # Copy certificates to container
    if [ -n "$certdir" ] && [ -f "$certdir/fullchain.pem" ] && [ -f "$certdir/privkey.pem" ]; then
        banner "Copy certificates to container"
        local CERT=$(cat $certdir/fullchain.pem)
        local KEY=$(cat $certdir/privkey.pem)
        DOCKEROUTPUT=$(docker exec -i $SCENARIO_ONCE_CONTAINER bash -s << EOF
            source /root/.once
            cd \$ONCE_DEFAULT_SCENARIO
            mv once.cert.pem once.cert.pem.bak
            mv once.key.pem once.key.pem.bak
            echo "$CERT" > once.cert.pem
            echo "$KEY" > once.key.pem
            ls once.*.pem
            openssl x509 -noout -fingerprint -sha256 -inform pem -in once.cert.pem 
            openssl x509 -noout -fingerprint -sha1 -inform pem -in once.cert.pem 
            openssl x509 -noout -text -inform pem -in once.cert.pem 
EOF
)
        logVerbose "$DOCKEROUTPUT"
    fi

    # Reconfigure ONCE server and connect structr
    banner "Reconfigure ONCE server and connect structr (in container $SCENARIO_ONCE_CONTAINER)"
    DOCKEROUTPUT=$(docker exec -i $SCENARIO_ONCE_CONTAINER bash -s << EOF
        source /root/.once
        export ONCE_REVERSE_PROXY_CONFIG='[["auth","test.wo-da.de"],["snet","test.wo-da.de"],["structr","${SCENARIO_STRUCTR_CONTAINER}:8083"]]'
        export ONCE_REV_PROXY_HOST='0.0.0.0'
        export ONCE_STRUCTR_SERVER='https://$SCENARIO_SERVER_NAME:$SCENARIO_RESOURCE_ONCE_REVERSEPROXY_HTTPS'
        CF=\$ONCE_DEFAULT_SCENARIO/.once
        mv \$CF \$CF.ORIG
        cat \$CF.ORIG | sed "s;ONCE_REVERSE_PROXY_CONFIG=.*;ONCE_REVERSE_PROXY_CONFIG='\$ONCE_REVERSE_PROXY_CONFIG';" | \
                        sed "s;ONCE_REV_PROXY_HOST=.*;ONCE_REV_PROXY_HOST='\$ONCE_REV_PROXY_HOST';" | \
                        sed "s;ONCE_STRUCTR_SERVER=.*;ONCE_STRUCTR_SERVER='\$ONCE_STRUCTR_SERVER';" > \$CF
        echo "CF=\$CF"
        cat \$CF | grep ONCE_REVERSE_PROXY_CONFIG
EOF
)
    logVerbose "$DOCKEROUTPUT"

    # Checkout correct branch
    banner "Checkout correct branch (in container $SCENARIO_ONCE_CONTAINER)"
    local ENV_CONTENT=$(<$SCENARIO_SERVER_CONFIGSDIR/$SCENARIO_NAME_SPACE/$SCENARIO_NAME/.env)
    DOCKEROUTPUT=$(docker exec -i $SCENARIO_ONCE_CONTAINER bash -s << EOF
        cd /var/dev/EAMD.ucp
        git checkout $SCENARIO_SRC_ONCE_BRANCH > /dev/null 2>&1
        git reset --hard
        git pull
        (
            date && echo
            git status && echo
            echo http://$SCENARIO_SERVER_NAME:$SCENARIO_RESOURCE_ONCE_HTTP/EAMD.ucp/
            echo http://$SCENARIO_SERVER_NAME:$SCENARIO_RESOURCE_ONCE_HTTP/EAMD.ucp/apps/neom/CityManagement.html
            echo https://$SCENARIO_SERVER_NAME:$SCENARIO_RESOURCE_ONCE_HTTPS/EAMD.ucp/
            echo http://$SCENARIO_SERVER_NAME:$SCENARIO_RESOURCE_STRUCTR_HTTP/structr/
            echo https://$SCENARIO_SERVER_NAME:$SCENARIO_RESOURCE_STRUCTR_HTTPS/structr/
            echo
            echo "$SCENARIO_SERVER_CONFIGSDIR/$SCENARIO_NAME_SPACE/$SCENARIO_NAME/.env:"
            echo "$ENV_CONTENT"
            echo
            echo "/root/.once:"
            cat /root/.once
            echo
            source /root/.once
            echo "\$ONCE_DEFAULT_SCENARIO/.once:"
            cat \$ONCE_DEFAULT_SCENARIO/.once
        ) > ./installation-status.log
EOF
)
    logVerbose "$DOCKEROUTPUT"

    private.restart.once
}

function start() {
    # Start container
    banner "Start container"
    docker-compose -p $SCENARIO_NAME start
    if [ "$VERBOSITY" == "-v" ]; then
        docker ps | grep $SCENARIO_NAME
    fi

    private.restart.once
}

function private.restart.once () {
    # Start ONCE server
    banner "Start ONCE server"
    #docker exec $SCENARIO_ONCE_CONTAINER bash -c "source /root/.once && once restart"
    DOCKEROUTPUT=$(docker exec -i $SCENARIO_ONCE_CONTAINER bash -s << EOF
cd /var/dev/EAMD.ucp
source /root/.once
once restart > /dev/null 2>&1
sleep 5
once cat > restart.log
EOF
)
    logVerbose "$DOCKEROUTPUT"
    log "ONCE server restarted"
}

function stop() {
    # Stop container
    banner "Stop container"
    docker-compose -p $SCENARIO_NAME stop
    docker ps | grep $SCENARIO_NAME
}

function down() {
    # Handle volume
    SCENARIO_ONCE_VOLUME_NAME=$(calculateVolumeName)
    addToFile $SCENARIO_SERVER_CONFIGSDIR/$SCENARIO_NAME_SPACE/$SCENARIO_NAME/.env SCENARIO_ONCE_VOLUME_NAME
    REAL_VOLUME_NAME=${SCENARIO_ONCE_VOLUME_NAME}
    if [[ "$SCENARIO_ONCE_VOLUME_NAME" == "var_dev" ]]; then
        REAL_VOLUME_NAME=${SCENARIO_NAME}_${SCENARIO_ONCE_VOLUME_NAME}
    fi

    # Shutdown and remove containers
    banner "Shutdown and remove containers"
    docker-compose -p $SCENARIO_NAME down
    if [ "$VERBOSITY" == "-v" ]; then
        docker ps
    fi

    # Cleanup docker
    banner "Cleanup docker volumes and images"
    if [[ -z "$SCENARIO_RESOURCE_ONCE_SRCPATH" || "$SCENARIO_RESOURCE_ONCE_SRCPATH" == "none" ]]; then
        if [[ -z "$SCENARIO_RESOURCE_ONCE_VOLUME" || "$SCENARIO_RESOURCE_ONCE_VOLUME" == "none" ]]; then
            docker volume rm ${REAL_VOLUME_NAME}
            log "Removed volume ${REAL_VOLUME_NAME}"
        else
            log "Not removing volume ${SCENARIO_RESOURCE_ONCE_VOLUME}, seems to be custom volume"
        fi
    else
        log "Not removing volume ${SCENARIO_RESOURCE_ONCE_VOLUME}, seems to be a path"
    fi
    docker image prune -f

    # Remove structr dir and other stuff
    rm -rf structr

    # Test
    banner "Test"
    if [ "$VERBOSITY" == "-v" ]; then
        SCENARIO_ONCE_VOLUME_NAME=$(calculateVolumeName)
        REAL_VOLUME_NAME=${SCENARIO_ONCE_VOLUME_NAME}
        if [[ "$SCENARIO_ONCE_VOLUME_NAME" == "var_dev" ]]; then
            REAL_VOLUME_NAME=${SCENARIO_NAME}_${SCENARIO_ONCE_VOLUME_NAME}
        fi
        docker volume ls | grep ${REAL_VOLUME_NAME}
        tree -L 3 -a .
    fi
}

function test() {
    # Test
    # Print volumes, images, containers and files
    if [ "$VERBOSITY" == "-v" ]; then
        banner "Test"
        log "Volumes:"
        SCENARIO_ONCE_VOLUME_NAME=$(calculateVolumeName)
        REAL_VOLUME_NAME=${SCENARIO_ONCE_VOLUME_NAME}
        if [[ "$SCENARIO_ONCE_VOLUME_NAME" == "var_dev" ]]; then
            REAL_VOLUME_NAME=${SCENARIO_NAME}_${SCENARIO_ONCE_VOLUME_NAME}
        fi
        docker volume ls | grep ${REAL_VOLUME_NAME}
        log "Images:"
        docker image ls | grep $(echo $SCENARIO_SRC_ONCE_IMAGE | sed "s;:.*;;")
        docker image ls | grep ${SCENARIO_STRUCTR_IMAGE}
        log "Containers:"
        docker ps | grep ${SCENARIO_ONCE_CONTAINER}
        docker ps | grep ${SCENARIO_STRUCTR_CONTAINER}
        tree -L 3 -a .
    fi

    # Check EAMD.ucp git status
    banner "Check EAMD.ucp git status for $SCENARIO_SERVER_NAME - $SCENARIO_NAME"
    if [ "$VERBOSITY" == "-v" ]; then
        curl http://$SCENARIO_SERVER_NAME:$SCENARIO_RESOURCE_ONCE_HTTP/EAMD.ucp/installation-status.log
    fi

    # Check running servers
    banner "Check running servers"
    checkURL "EAMD.ucp repository (http)" http://$SCENARIO_SERVER_NAME:$SCENARIO_RESOURCE_ONCE_HTTP/EAMD.ucp/
    checkURL "EAMD.ucp installation status" http://$SCENARIO_SERVER_NAME:$SCENARIO_RESOURCE_ONCE_HTTP/EAMD.ucp/installation-status.log
    checkURL "EAMD.ucp repository (https)" https://$SCENARIO_SERVER_NAME:$SCENARIO_RESOURCE_ONCE_HTTPS/EAMD.ucp/ 
    checkURL "NEOM CityManagement app" https://$SCENARIO_SERVER_NAME:$SCENARIO_RESOURCE_ONCE_HTTPS/EAMD.ucp/apps/neom/CityManagement.html 
    checkURL "structr server (http)" http://$SCENARIO_SERVER_NAME:$SCENARIO_RESOURCE_STRUCTR_HTTP/structr/ 
    checkURL "structr server (https)" https://$SCENARIO_SERVER_NAME:$SCENARIO_RESOURCE_STRUCTR_HTTPS/structr/ 
    checkURL "structr server (https) login" https://$SCENARIO_SERVER_NAME:$SCENARIO_RESOURCE_STRUCTR_HTTPS/structr/rest/login  -XPOST -d '{ "name": "admin", "password": "*******" }'
    checkURL "structr server (https) login via reverse proxy (admin)" https://$SCENARIO_SERVER_NAME:$SCENARIO_RESOURCE_ONCE_REVERSEPROXY_HTTPS/structr/rest/login  -XPOST -d '{ "name": "admin", "password": "*******" }'
    checkURL "structr server (https) login via reverse proxy (NeomCityManager)" https://$SCENARIO_SERVER_NAME:$SCENARIO_RESOURCE_ONCE_REVERSEPROXY_HTTPS/structr/rest/login  -XPOST -d '{ "name": "NeomCityManager", "password": "secret" }'
    checkURL "structr server (https) login via reverse proxy (Visitor)" https://$SCENARIO_SERVER_NAME:$SCENARIO_RESOURCE_ONCE_REVERSEPROXY_HTTPS/structr/rest/login  -XPOST -d '{ "name": "Visitor", "password": "secret" }'
}

function printUsage() {
    log "Usage: $0 (up,start,stop,down,test)  [-v|-s|-h]"
    exit 1
}

# Scenario vars
if [ -z "$1" ]; then
    printUsage
    exit 1
fi

STEP=$1
shift

VERBOSEPIPE="/dev/null"

# Parse all "-" args
for i in "$@"
do
case $i in
    -v|--verbose)
    VERBOSITY=$i
    VERBOSEPIPE="/dev/stdout"
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