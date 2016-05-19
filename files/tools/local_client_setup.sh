#!/bin/bash

set -e

if [[ $(docker inspect -f "{{ .State.Paused }}" aci 2>/dev/null) ]]; then

  mustDeployAgents=false

  if [[ $(docker inspect -f "{{ .State.Paused }}" squid-deb-proxy 2>/dev/null) ]]; then
    docker start squid-deb-proxy
  else
    mustDeployAgents=true
  fi

  if [[ $(docker inspect -f "{{ .State.Paused }}" docker-mirror 2>/dev/null) ]]; then
    docker start docker-mirror
  else
    mustDeployAgents=true
  fi

  echo 'ACI container already exists. Starting...'
  docker start aci

  if [[ "$mustDeployAgents" = 'true' ]]; then
    echo 'However your agent is not fully running, so you have to run following command again:'
    echo ''
    echo '    docker exec -it aci deploy-agents'
  fi

  exit
fi

if [[ ! -d clientconfig ]]; then
  echo 'It seems to be the first time running ACI at this workspace location:'
  echo -e "\n\t$(pwd)\n"
  read -p 'Do you want to create a new workspace in this directory? (y/n): ' -e -i 'n' createworkspace
  if [[ "$createworkspace" != 'y' ]]; then
    echo 'exiting...'
    exit
  else
    mkdir clientconfig
  fi
fi

if [[ ! -f clientconfig/repositories.yml ]]; then

  echo -e "---\naci_repository:" > clientconfig/repositories.yml

  clear
  echo 'Configuration Check [..    ]'
  echo ''
  echo 'Your workspace did not contain a repository configuration, therefore a new one was created.'
  echo 'The configuration contains information of how the repository is structured, meaning in'
  echo ' which (sub) directories the roles and playbooks are located.'
  echo 'The physical location of the repository is gathered in a later step.'
  echo 'Please provide following information:'

  addNextRepo=true
  while [[ $addNextRepo = 'true' ]]; do
    unset repolabel
    unset rolespath
    unset playbookspath
    unset rolesfrom
    echo ''
    read -p ' An arbitrary but unique label identifying your repository: ' -e -i 'default' repolabel
    read -p ' The relative subpath in the repo containing the roles (leave blank if root or none): ' rolespath
    read -p ' The relative subpath in the repo containing the playbooks (leave blank if root or none): ' playbookspath
    read -p ' A list of repository labels to gather roles from (leave blank if none): ' rolesfrom

    echo "  - name: $repolabel" >> clientconfig/repositories.yml
    if [[ $rolespath ]]; then echo "    subpath_roles: $rolespath" >> clientconfig/repositories.yml; fi
    if [[ $playbookspath ]]; then echo "    subpath_playbooks: $playbookspath" >> clientconfig/repositories.yml; fi

    if [[ ! -z "$rolesfrom" ]]; then
      echo "    roles_path_from:" >> clientconfig/repositories.yml
      for label in $rolesfrom; do
        echo "      - $label" >> clientconfig/repositories.yml
      done
    fi

    read -p ' Would you add one more repository? (y/n): ' -e -i 'n' oneMoreRepo
    if [[ "$oneMoreRepo" != 'y' ]]; then
      addNextRepo=false
    fi
  done
fi

if [[ ! -f clientconfig/conf_repository_path ]]; then
  clear
  echo 'Configuration Check [....  ]'
  echo ''
  echo "ACI needs to know the local locations of your repositories."
  echo 'This information is machine specific, thus being automatically added to .gitignore.'
  echo ''
  touch clientconfig/conf_repository_path
fi

# collect the local paths to the repos
for repo in $(grep 'name: ' clientconfig/repositories.yml | cut -c 11-); do
  set +e; grep -q "/var/jenkins_home/workspace/develop/$repo" clientconfig/conf_repository_path; rc=$?; set -e
  if [[ $rc != 0 ]]; then
    read -p " Please provide the absolute path to the repository with the label '${repo}': " -e -i "${HOME}/" repopath
    echo "-v $repopath:/var/jenkins_home/workspace/develop/$repo" >> clientconfig/conf_repository_path
  fi
done

if [[ ! -f clientconfig/vault.yml ]]; then
  echo "PKI_PASSWORD: $(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1)" > clientconfig/vault.yml

  echo 'ACI_PRIVATE_KEY: |' >> clientconfig/vault.yml
  ssh-keygen -t rsa -C 'AnsibleCI' -N '' -f /tmp/aci_key 1>/dev/null
  cat /tmp/aci_key | sed 's/^/  /' >> clientconfig/vault.yml
  echo "ACI_PUBLIC_KEY: $(cat /tmp/aci_key.pub)" >> clientconfig/vault.yml

  cat /tmp/aci_key.pub >> ~/.ssh/authorized_keys
  rm /tmp/aci_key /tmp/aci_key.pub

  echo 'ACIA_PRIVATE_KEY: |' >> clientconfig/vault.yml
  ssh-keygen -t rsa -C 'ACIAgent' -N '' -f /tmp/acia_key 1>/dev/null
  cat /tmp/acia_key | sed 's/^/  /' >> clientconfig/vault.yml
  echo "ACIA_PUBLIC_KEY: $(cat /tmp/acia_key.pub)" >> clientconfig/vault.yml
  rm /tmp/acia_key /tmp/acia_key.pub

  clear
  echo 'Configuration Check [......]'
  echo ''
  echo 'Your workspace did not contain a vault file, therefore a new one was created.'
  echo 'This is an encrypted file containing unique and secret information for this ACI instance.'
  echo 'This information is machine specific, thus being automatically added to .gitignore.'
  echo 'Please provide the Vault Password.'
  echo 'You will be asked for this password whenever you start ACI from this workspace.'
  echo ''
  ansible-vault encrypt clientconfig/vault.yml
fi

# create .gitignore
if [[ ! -f .gitignore ]]; then touch .gitignore; fi
# add files to .gitignore if not already present
for file in vault.yml conf_repository_path; do
  grep -q -F "clientconfig/$file" .gitignore || echo "clientconfig/$file" >> .gitignore
done

clear
echo 'Starting ACI with...'
read -s -p 'Vault Password:' avp && echo ''

docker run -d \
  --name aci \
  -p 8081:8080 \
  -e "ANSIBLE_VAULT_PASSWORD=$avp" \
  -e "ACIA_LOGIN_USER=$(whoami)" \
  -v "$(pwd)/clientconfig":/ansible_config \
  $(cat clientconfig/conf_repository_path) \
  iteratechh/jenkins 1>/dev/null

echo ''
echo 'The AnsibleCI Docker container has been started.'
echo 'You can monitor the startup and further logs with'
echo ''
echo '    docker logs -f aci'
echo ''
echo 'After a while ACI will be available on http://localhost:8081'
echo ''
echo 'When ACI is up and running you have to complete the setup by'
echo 'running the installation of the local Vagrant Agent by running'
echo ''
echo '    docker exec -it aci deploy-agents'
