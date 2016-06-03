#!/bin/bash

set -e

function checkout_custom_repo(){
  if [[ -f /used_config/conf_ansible_repository ]]; then
    cd /ansible_custom
    rm -rf * .[a-zA-Z0-9]*
    git clone "$(cat /used_config/conf_ansible_repository | head -n 1)" --recursive .
  fi
}

function setup_aci(){

  if [[ $# -lt 1 ]] && [[ -z $ANSIBLE_VAULT_PASSWORD ]] && [[ -z $ACIA_LOGIN_USER ]]; then
    echo -e '\nFor local usage of ACI create a new, empty workspace folder, run the'
    echo 'following commands inside and follow the instructions: '
    echo ''
    echo '  docker run --rm iteratechh/ansibleci get-local-start-script > aci_local.sh'
    echo '  chmod +x aci_local.sh'
    echo '  ./aci_local.sh'
    echo ''
    echo 'For deploying ACI on a remote server get further documentation by'
    echo 'running the following command:'
    echo ''
    echo -e '  docker run --m iteratechh/ansibleci help\n'
    exit
  fi

  # execute default Docker jenkins start script
  /usr/local/bin/jenkins.sh date 1>/dev/null # pass 'date' to suppress startup of jenkins

  # for any deployment gather vault password
  if [[ $# -lt 1 ]] || [[ "$1" == "--"* ]] || [[ "$1" == 'deploy-aci' ]] || [[ "$1" == 'deploy-agents' ]] || [[ "$1" == 'deploy-prelive' ]]; then
    if [[ -z $ANSIBLE_VAULT_PASSWORD ]]; then
      echo "You have to provide the vault password through the ANSIBLE_VAULT_PASSWORD variable."
      exit 1
    fi
    echo "$ANSIBLE_VAULT_PASSWORD" > /tmp/ansible_vaultpass
  fi

  # for any deployment despite the prelive deployment gather agents login user if file not already present
  if [[ ! -f /used_config/agent_user.yml ]] && ([[ $# -lt 1 ]] || [[ "$1" == "--"* ]] || [[ "$1" == 'deploy-aci' ]] || [[ "$1" == 'deploy-agents' ]]); then
    if [[ -z $ACIA_LOGIN_USER ]]; then
      echo "You have to provide the user for logging onto the ACI agents machine through the ACIA_LOGIN_USER variable."
      exit 1
    fi
    echo "acia_login_user: $ACIA_LOGIN_USER" > /used_config/agent_user.yml
  fi

  # 'Install' ACI into Jenkins
  if [[ $# -lt 1 ]] || [[ "$1" == "--"* ]]; then
    cd /ansible_data/playbooks/setup
    ansible-playbook --vault-password-file /tmp/ansible_vaultpass site.yml
  fi
}


## Start of definition of singleton functions

if [[ $1 == 'help' ]]; then
  echo -e '\nCLI documentation coming soon.'
  echo -e 'Please refere meanwhile to the documentation of the Docker repository.\n'
  exit
fi

if [[ $1 == 'get-local-start-script' ]]; then
  cat /tools/local_client_setup.sh
  exit
fi

## End of definition of singleton functions

# update used configuration
if [[ $(ls /ansible_config/) ]]; then
  cp /ansible_config/* /used_config
fi

if [[ ! -f /var/jenkins_home/.aci_installed ]]; then
  setup_aci
  checkout_custom_repo
  touch /var/jenkins_home/.aci_installed
fi

# initiate default startup if no other commands than jenkins parameters are passed...
if [[ $# -lt 1 ]] || [[ "$1" == "--"* ]]; then
  exec java $JAVA_OPTS -jar /usr/share/jenkins/jenkins.war $JENKINS_OPTS "$@"
fi

# ...or execute the command given
exec "$@"
