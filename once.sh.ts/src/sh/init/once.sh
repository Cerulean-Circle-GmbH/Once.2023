#!/bin/sh
#http://www.etalabs.net/sh_tricks.html

export PS4='sh debug> '

# find all set -x
#  '^ *[^#] *set -x'
set -x
# force debug

#unset SHELL
oosh_get_running_shell() 
{
  #SHELLNAME="$(ps -o pid,args | grep "\w*$$ [^g]*sh" | awk '{$1=$1};1' | cut -d\  -f2 | sed s/-//)"
  SHELLPS="$(ps -o pid,args | grep "\w*$$ [^g]*/sh")"
  SHELL=$(which "$SHELLNAME")
}

log()
{
  if [ "$LOG_LEVEL" -gt 4 ]; then
    echo "$@"
  fi
} 

oosh_check_pm()             # checks for a package manager
{
    packageManager=$1
    packageManagerCommand=$2


    if [ -z "$packageManagerCommand" ]; then
        package=$packageManager
    fi   
    if ! [ -x "$(command -v $packageManagerCommand)" ]; then
        log "no $packageManagerCommand"
    else
        if [ -z "$OOSH_PM" ]; then
            export OOSH_PM="$packageManagerCommand"
            #export groupAddCommand=$2
            #export userAddCommand=$3
            log "Package Manager found: using $OOSH_PM somePackage"
            if [ "$packageManager" = "apt-get" ]; then
                if [ -z "$OOSH_PM_UPDATED" ]; then
                  OOSH_PM_UPDATED="$SUDO apt-get update"
                  if [ "$HOME" = "/root" ]; then
                    $OOSH_PM_UPDATED
                  else
                    #sudo $OOSH_PM_UPDATED
                    PM="sudo $PM"
                    SUDO="sudo "
                    $SUDO $OOSH_PM_UPDATED
                  fi
                else
                  log "in case of installation errors try to call: apt-get update"
                fi
            fi
        fi
    fi
}

oosh_check_all_pm()         # adds tools and configurations to package manager (brew, apt-get, addgroup, adduser, dpkg, pkg)
{

    oosh_check_pm brew "brew install"    
   #oosh_check_pm apt "apt add"
    oosh_check_pm apt-get "apt-get -y install" "groupadd -f" "useradd -g dev"
    oosh_check_pm apk "apk add" "addgroup" "adduser -g dev"
    oosh_check_pm dpkg "dpkg install"
    oosh_check_pm pkg "pkg install"
    #oosh_check_pm pacman "pacman -S"
 
}

oosh_check_os() # check on which Operating System oosh is being deploid on #
{
  if ! [ -x "$( command -v oo )" ]; then
   info.log "no os script class installed yet"
   return 1
  fi
  if os check.env; then
    info.log "OS detected and OOSH_OS populated with $OOSH_OS"
  else
    error.log "NO OS detected"
  fi

  exit 
}

oosh_cmd() 
{
    unset package
    current=$1
    shift
    if [ -n "$1" ]; then
      package=$1
      shift
    fi
    if [ -z "$package" ]; then
        package=$current
    else
      shift
      package=$1
    fi

    if [ -z "$OOSH_OS" ]; then
      echo "no OS found...checking" 
      #oosh_check_os
    fi
    
    if [ -z "$OOSH_PM" ]; then
      echo "no PM found...checking" 
      oosh_check_all_pm
    fi
    if ! [ -x "$(command -v $current)" ]; then
        echo "no $current"
        if [ -n "$OOSH_PM" ]; then
          $SUDO $OOSH_PM $package
        else
          echo "still no PM found: $OOSH_PM $package"
        fi
    # else
    #   echo "command $current exists"
    fi
}

oosh_install_oosh()
{

  oosh_cmd git
  cd ~
  #if [ -z "$OOSH_DIR" ]; then
    OOSH_DIR="$(pwd)/oosh"
  #fi


  if ! [ -d "$OOSH_DIR" ]; then
    #set -x # force debug
    git clone https://github.com/Cerulean-Circle-GmbH/once.sh.git
    if [ -f ./oosh ]; then
      mkdir -p ./init
      mv ./oosh ./init
      chmod +x ./init/oosh
    fi
    mv ./once.sh ./oosh
    cp -r ~/oosh/init/* ~/init
    
    ### temporary for testing
    if [ -n "$DEV_MODE" ]; then
      cd "$OOSH_DIR"
      git checkout -t origin/dev
    fi
    ###
  else
    cd "$OOSH_DIR"
    git pull
    cd ..
  fi
}

oosh_status()
{
  if [ "$HOME"  = "/root" ];then
    SUDO=""
    if [ -z "$USER" ];then
      export USER=root
    fi
  else
    SUDO="sudo -S"
  fi

  echo "
  SHELL: $SHELL
       : $SHELLNAME
       : $SHELLPS
    PWD: $(pwd)
      0: $0

     PM: $OOSH_PM
         $OOSH_PM_UPDATED 

   BASH: $BASH_FILE
      v: $BASH_MAJOR_VERSION

   INSTALL_MODE: $INSTALL_MODE
       DEV_MODE: $DEV_MODE

   USER: $USER 

   PATH: $PATH
  "
}

oosh_parse_shellps() 
{
  if [ -n "$1" ]; then
    shell_pid=$1
    shift
  fi
  script=$1
  shell=$1
  if [ "$(echo $script | cut -c 1)" = "{" ]; then
    #echo script=$script
    shift
    shell=$1
  else
    #echo shell=$script
    shell=$script
    script=$2
  fi
  this=$2

  log " 
    shell: $shell
      pid: $shell_pid
   script: $script
     this: $this
  "
  SHELL=$shell

}


oosh_start() 
{
  if [ -n "$1" ]; then
    echo "got parameters: $@"
    while [ -n $1 ]; do
      case $1 in
        mode)
          echo "got: $*"
          shift
          INSTALL_MODE="$1"
          shift
          echo "having: $*"
          
          if [ -n "$1" ]; then
            echo "name used by remote for this ssh connection: $1"
            export SSH_CONFIG_NAME_USED_FOR_LOCAL="$1"
            shift
          fi
          
          if [ -n "$1" ]; then
            echo "name of the remote ssh connection: $1"
            export SSH_CONFIG_FROM_REMOTE="$1"
            shift
          fi

          if [ "$1" = "dev" ]; then
            echo "dev mode: $1"
            export DEV_MODE="$1"
            shift
          fi
          break
        ;;
        *)
          echo "this.call to: $*"
          #this.call "$@"
          shift
      esac
    done
    #return 0 
  fi

  if [ -z "$LOG_LEVEL" ]; then
    LOG_LEVEL=3
  fi

  # if [ -r /root ]; then
  #   cd /root
  # fi

  oosh_get_running_shell
  oosh_parse_shellps $SHELLPS
  SHELLNAME=$(basename $SHELL)
  BASH_FILE=$(which bash)
  if [ -n "$BASH_FILE" ]; then
    echo BASH_MAJOR_VERSION=$("$BASH_FILE" -c "echo \"\${BASH_VERSINFO[0]}\"")
    BASH_MAJOR_VERSION=$("$BASH_FILE" -c "echo \"\${BASH_VERSINFO[0]}\"")
  fi

  #oosh_check_os
  oosh_check_all_pm
  oosh_status
  oosh_install_oosh

  #set
  # TODO remove -xc in Bash 
  if [ "$INSTALL_MODE" = "ssh" ]; then
    echo done with SSH installation....
    echo try to continue local....
    # TODO remove -xc in Bash 
    "$BASH_FILE" -xc "$OOSH_DIR/this call ossh install.continue.local $SSH_CONFIG_FROM_REMOTE $SSH_CONFIG_NAME_USED_FOR_LOCAL $DEV_MODE"
    echo done with ssh installation....
    echo Bye
    return 0
  fi

  if [ "$INSTALL_MODE" = "user" ]; then
    echo done with USER installation....
    echo try to continue local as root....
    # TODO remove -xc in Bash 
    "$BASH_FILE" -xc "$OOSH_DIR/this call ossh install.continue.local $SSH_CONFIG_FROM_REMOTE $SSH_CONFIG_NAME_USED_FOR_LOCAL $DEV_MODE"
    echo done with user installation....
    echo Bye
    return 0
  fi

  if [ "$SHELLNAME" = "bash" ]; then
    echo "BASH Version: $BASH_VERSION[@]"
  else
    echo "not in bash: bash is in $BASH_FILE"
    if [ -n "$BASH_FILE" ]; then
      echo "starting bash -x $OOSH_DIR/this localInstall"
      "$BASH_FILE" -x "$OOSH_DIR"/this localInstall
    else
      oosh_cmd bash
      export BASH_FILE=$(which bash)
      echo "starting bash -x $OOSH_DIR/this localInstall"
      "$BASH_FILE" -x "$OOSH_DIR"/this localInstall
    fi
  fi
}

oosh_start "$@"
