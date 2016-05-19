# Server Installation

## 1 Create the Configuration

Get the example configuration and modify according your needs:

```
docker run --rm -v "$(pwd)":/config iteratechh/jenkins cp -a /example_config /config
mv example_config ansible_config
```

## 2 Start ACI with Configuration

```
#!/bin/bash
echo 'Vault Password: '
read -s avp
docker run -d --name aci -p 8081:8080 --env "ANSIBLE_VAULT_PASSWORD=$avp"
  -v /path/to/ansible_config:/ansible_config
  -v /path/to/repository:/var/jenkins_home/workspace/develop/<repo-label>
  iteratechh/jenkins

```

## 3 Deploy ACI Agent

```
docker exec -it aci deploy-agents
```
