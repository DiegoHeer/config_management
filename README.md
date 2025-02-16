# Configuration management

This repo contains personal configuration management for automatically setting up Ubuntu home servers, laptops, and desktops. The following features are available:

- Ansible playbooks for automatic configuration
- Restic Profile for auto/manual configuration of backups, using the 3-2-1 Backup rule
- Docker compose files for spinning up personal home lab services

For the usage of ansible playbooks, see the [Ansible](#ansible) section. For manual configuration of docker services and backups, see the [Manual](#manual) section.

## Ansible

### Requirements

- A server/pc with Ubuntu 24.04 installed (other ubuntu versions/linux distros where not tested)
- python >= 3.11
- poetry >= 2.0.0

### Setup

1. Install packages with poetry. Afterwards, install ansible galaxy roles:

```bash
    poetry install
    poetry run ansible-galaxy install -r requirements.yml
```

2. An SSH key is required on the host machine. If not yet available, create one with the command below. If prompted for passphrases, skip them since they are not required.

```bash
    ssh-keygen -t ed25519 -C <email address>
```

3. Add the public ssh key to all the hosts you want to manage (repeat this command for every host):

```bash
    ssh-copy-id -i ~/.ssh/id_ed25519 <host user>@<host ip address>
```

4. Next, edit the `inventory.yml` file. Add additional hosts if required, and change variables.

5. Test if there is connection with the defined hosts. In case there is no connection, check if the ssh keys & inventory file are configured correctly. For more info, check the official [Ansible documentation](https://docs.ansible.com/ansible/latest/getting_started/index.html) for further instructions.

```bash
    poetry run ansible <host group (check inventory file)> -m ping
```
6. **Done!**

### Usage

1. Create a `.vault_key` file in the root directory of this repo, and fill it with your Ansible vault password. Every `vault.yml` file requires this password to be decrypted. Substitute all `vault.yml` files in all the local roles if needed (you will have to go through each task to verify which variable came from an `vault.yml` file).

2. Run the ansible playbook with the command below. The location of the vault key file is already defined in the `ansible.cfg` file:

```bash
    poetry run ansible=playbook <playbook file>
```

Optionally, it is possible to run Ansible playbooks with the command below:

```bash
    poetry run ansible-playbook playbooks/<playbook file> --ask-vault-pass
```
When prompted, fill in with the vault password.

#### Optional Usage

Playbooks can also be run locally (e.g. on the server) using the `ansible-pull` command, together with the github repository:

```bash
    sudo apt update
    sudo apt install ansible -y
    ansible-pull -U git@github.com:DiegoHeer/config_management.git --vault-password-file .vault_key --ask-become-pass
```
For more info on this method, check this [video](https://www.youtube.com/watch?v=sn1HQq_GFNE&t=1715s).

### Testing

Testing of Ansible roles & playbooks is done with [Molecule](https://ansible.readthedocs.io/projects/molecule/).
To test a role run the following command:

```bash
    molecule test -s <role name>
```
The available role names are: `system`, `projects`, `development`, `gui`, `restore`, `services`

To check internally if everything setup correctly in the Molecule test container, use these commands:

```bash
    molecule converge -s <role name>
    molecule login -s <role name>
```

For destroy Molecule test containers, use this command:

```bash
    molecule destroy -s <role name>
```

To create a new test scenario (e.g. for a new role or playbook):

```bash
    molecule init scenario <role/playbook name>
```

After the creation of the new scenario, delete the `creation.yml` and `destroy.yml`,
and edit the `molecule.yml` file to have the same setup as the other scenarios.
Also update the `converge.yml` file to use the new role/playbook.


## Manual

### Backups

1. Automatic backups are done using Restic and Restic Profile. The backup strategy used is the 3-2-1 Backup Rule, which states that there should always be 3 copies of your data, with one backup on a different media type (e.g. HDD, usb stick, local server), and another on a offsite location (e.g. cloud).

Check the links for more info about [Restic](https://restic.net) and [Restic Profile](https://creativeprojects.github.io/resticprofile/index.html).

To proceed with Restic Profile using the existing `profiles.yaml` configuration file, first be sure to have restic and restic profile installed:

```bash
    sudo apt install restic curl -y
    curl -sfL https://raw.githubusercontent.com/creativeprojects/resticprofile/master/install.sh | sh
```

2. Enter in the backup folder:

```bash
    cd backup
```

3. Also be sure to have a file ready with a restic password (fill in the placeholder):

```bash
    echo <password> > .resticprofile_key
```

3. Create an `.env` file by copying the `.env.template` file, and fill in the required environment variables.

4. Edit the `profile.yaml` file if needed, mainly the locations of the backup sources and repositories to your liking.

5. To see the available backup profiles, use this command:

```bash
    resticprofile profiles
```

6. To initialize a non-existing or new repository, run the following (fill in the placeholder):

```bash
    resticprofile -n <profile name> init
```

7. To check existing snapshots on a restic repository:

```bash
    resticprofile -n <profile name> snapshots
```

8. To run a backup:

```bash
    resticprofile -n <profile name> backup
```

9. To restore, use the following command. Be sure to have created the target folder beforehand:

```bash
    resticprofile -n <profile name>  restore latest --target <target directory>
```

### Docker Compose Services

1. Enter the `services` folder:

```bash
    cd services
```

2. Create an `.env` file by copying the `.env.template` file, and fill in the required environment variables.

3. Check if all the folders/files of mounted volumes exist locally (go through each docker compose file). To guarantee they exist locally, you can also restore them using restic profile:

```bash
    cd ../backup
    export $(grep -v "^#" .env | xargs -d "\n")
    resticprofile -n services restore latest --target /
```

4. Pull and start the docker compose services:

```bash
    docker compose up -d
```
