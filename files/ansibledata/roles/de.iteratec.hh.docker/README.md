# thomass.docker
Installs latest docker-engine from the official Docker repository.

It also creates three cool aliases:

parameter                      | that runs
------------------------------ | ------------------------------------------------
`d`                            | `docker`
`dcompose`                     | `docker-compose`
`dbox <param1> <param2> <...>` | `docker run -it --rm --name dbox $* ubuntu bash`

## Info
Mention common information in parent [README.md](../README.md)

## Remote Access (advanced topic)

You can make Docker listen on all interfaces for client requests. This playbook is automaticall creating a PKI with keys and certificates for the Docker server and clients. All PKI files nescessary for the client will be downloaded to the Ansible control machine, as well as an alias is created for calling the remote Docker server.

The setup of the remote access is triggered by setting a value for the variable `docker_server_domain`. Here an example:

```
- role: thomass.docker
  docker_server_domain: "example.com"
  docker_server_ip: "93.184.216.34"
  docker_server_port: 4243
  docker_pki_password: "notthatlush"
  docker_pki_countrycode: "DE"
  docker_pki_state: "Sachsen"
  docker_pki_locality: "Zwickau"
  docker_pki_organization: "Example Ltd."
  docker_client_user_home: /home/user
```

The variable `docker_server_ip` is optional as Ansible tries to figure out the default IPv4 address.

The variable `docker_client_user_home` is the home directory of the client under which the credentials for the remote docker server are stored.

After running the Playbook the alias `dremote_example.com` is created on the Ansible control machine, which executes Docker commands on example.com. Here an example:

```
dremote_example.com version
dremote_example.com run -it --rm ubuntu bash
```

The Alias could be manually set by setting the value to the variable `docker_remote_alias` or avoided with `docker_create_remote_alias: no`.

## Return Value

If the role setups remote access it would return the variable `docker_remote_connection_args`. It contains all parameters Docker neeeds to connect to the remote client and could be used by the Ansible Docker Connection PlugIn.

## Known Bugs
- The group _docker_ was added to the login user, such that he doesn't need sudo privileges to execute docker. But the group policy would be just available on the next Ansible run. Thus the docker role must be run in a prior separate playbook to make the group policy work.

## Licence
The whole repository is licenced under BSD. Please mention following:

gitlab.xarif.de / ThomasSteinbach (thomass at aikq.de)
