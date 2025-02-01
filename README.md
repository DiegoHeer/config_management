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
    ssh-keygen -t ed25519 -C <email address>
```

3. Add the public ssh key to all the hosts you want to manage (repeat this command for every host):

```bash
    ssh-copy-id -i ~/.ssh/id_ed25519 <host user>@<host ip address>
```

4. Next, edit the `inventory.yml` file. Add here additional hosts if required.

5. Test if there is connection with the defined hosts. In case there is no connection, either there is no connection to the hosts, ssh keys and/or inventory file are configured incorrectly. Check official [Ansible documentation](https://docs.ansible.com/ansible/latest/getting_started/index.html) for further instructions. 

```bash
    poetry run ansible <host group (check inventory file)> -m ping
```
6. **Done!**

### Optional settings

To use playbooks that require sensible variables, such as passwords, API keys, and access tokens, an encrypted variable file can be created to store them:

```bash
    cd ./group_vars/all
    poetry run ansible-vault create secret.yml
```
A passphrase will be required. Afterwards, a text editor will open where you can write these variables. To exit the editor, type `esc` and `:x`.

To edit the `secret.yml` file, use the following command:

```bash
    poetry run ansible-vault edit secret.yml
```

## Usage

Run ansible playbooks with the command below:

```bash
    poetry run ansible-playbook playbooks/<playbook file> --ask-vault-pass
```
The first prompted passphrase refers to accessing the `secret.yml` file with ansible vault.

Optionally, to reduce the amount of password entries required, the following can be done:
1. Create a `vault_key` file in the root directory and place there your vault password
2. Run the ansible playbook with the following command:

```bash
    poetry run ansible=playbook <playbook file> --vault-password-file vault_key
```

### Optional Usage

Playbooks can also be run locally (e.g. on the server) using the `ansible-pull` command, together with the github repository:

```bash
    sudo apt update
    sudo apt install ansible -y
    ansible-pull --vault-password-file= vault_key -U https://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@github.com/DiegoHeer/config_management.git
```
If the token key is not valid anymore, generate a new one and place it in the https github url.

For more info on this method, check this [video](https://www.youtube.com/watch?v=sn1HQq_GFNE&t=1715s).