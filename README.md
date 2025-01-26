# Ansible Configuration management

This repo contains ansible playbooks to automatically configure personal servers, laptops, and desktops.

## Getting Started

1. Install packages with poetry (>2.0.0). Afterwards, install ansible galaxy roles:

```bash
    poetry install
    poetry run ansible-galaxy install -r requirements.yml
```

2. Also, an SSH key is required on the host machine. If not yet available, create it with the command below. If prompted for passphrases, skip them since they are not required.

```bash
    ssh-keygen -t ed25519 -f ~/.ssh/key -C <email address>
```

3. Add the public ssh key to all the hosts you want to manage (repeat this command for every host):

```ssh
    ssh-copy-id -i ~/.ssh/key <host user>@<host ip address>
```

4. Next, create a `hosts.yml` file by copying the `hosts.yml.template`. Fill in the blanks as required (each host per line):

```ssh
    cp ./inventory/hosts.yml.template ./inventory/hosts.yml
```

5. Test if there is connection with the defined hosts. In case there is no connection, either there is no connection to the hosts, ssh keys and/or hosts file are configured incorrectly. Check official [Ansible documentation](https://docs.ansible.com/ansible/latest/getting_started/index.html) for further instructions. 

```ssh
    poetry run ansible <host group (check hosts file)> -m ping
```
6. **Done!**

### Optional settings

To use playbooks that require sensible variables, such as passwords, API keys, and access tokens, an encrypted variable file can be created to store them:

```ssh
    cd ./group_vars/all
    poetry run ansible-vault create secret.yml
```
A passphrase will be required. Afterwards, a text editor will open where you can write these variables. To exit the editor, type `esc` and `:x`.

To edit the `secret.yml` file, use the following command:

```ssh
    poetry run ansible-vault edit secret.yml
```

## Usage

Run ansible playbooks with the command below:

```ssh
    poetry run ansible-playbook run.yml -K --ask-vault-pass
```
The first prompted passphrase refers to sudo permissions for the host, and the second one for accessing the `secret.yml` file with ansible vault:
