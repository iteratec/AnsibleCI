
#!/bin/bash
if [[ ! -d serverconfig ]]; then
  echo 'It seems to be the first time running ACI at this workspace location:'
  echo -e "\n\t$(pwd)\n"
  read -p 'Do you want to create a new workspace in this directory? (y/N): ' createworkspace
  if [[ -z "$createworkspace" ]] || [[ "$createworkspace" != 'y' ]]; then
    echo 'exiting...'
    exit
  else
    mkdir serverconfig
  fi
fi

if [[ ! -f serverconfig/vault.yml ]]; then
  echo "PKI_PASSWORD: $(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1)" > serverconfig/vault.yml

  echo 'ACI_PRIVATE_KEY: |' >> serverconfig/vault.yml
  ssh-keygen -t rsa -C 'AnsibleCI' -N '' -f /tmp/aci_key 1>/dev/null
  cat /tmp/aci_key | sed 's/^/  /' >> serverconfig/vault.yml
  echo "ACI_PUBLIC_KEY: $(cat /tmp/aci_key.pub)" >> serverconfig/vault.yml

  cat /tmp/aci_key.pub >> ~/.ssh/authorized_keys
  rm /tmp/aci_key /tmp/aci_key.pub

  echo 'ACIA_PRIVATE_KEY: |' >> serverconfig/vault.yml
  ssh-keygen -t rsa -C 'ACIAgent' -N '' -f /tmp/acia_key 1>/dev/null
  cat /tmp/acia_key | sed 's/^/  /' >> serverconfig/vault.yml
  echo "ACIA_PUBLIC_KEY: $(cat /tmp/acia_key.pub)" >> serverconfig/vault.yml
  rm /tmp/acia_key /tmp/acia_key.pub

  clear
  echo 'Your workspace did not contain a vault file, therefore a new one was created.'
  echo 'This is an encrypted file containing unique and secret information for this ACI instance.'
  echo 'This information is machine specific, thus being automatically added to .gitignore.'
  echo 'Please provide the Vault Password.'
  echo 'You will be asked for this password whenever you start ACI from this workspace.'
  echo ''
  ansible-vault encrypt serverconfig/vault.yml
fi

clear
echo 'Starting ACI with...'
read -s -p 'Vault Password:' avp && echo ''

docker run -it --rm \
  -e "ANSIBLE_VAULT_PASSWORD=$avp" \
  -v "$PWD/serverconfig":/ansible_config \
  -v "$HOME/.ssh:/var/jenkins_home/.ssh" \
  iteratechh/ansibleci deploy-remote

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
