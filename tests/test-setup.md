# Configuration tests

The configuration management created can be tested on local docker container instances.
To provision the resources required for testing, please run (in terraform folder):

```bash
    terraform apply -auto-approve
```

To test a specific playbook, run the following command (note that a new inventory.yml is created, and that there already should be an `.vault_key` file in the root directory with the vault password):

```bash
    poetry run ansible-playbook tests/<TEST FILE>.yml -i tests/inventory.yml
```

Ssh into the machine to check if everything is according to expectations:

```bash
    SSH_COMMAND="$(terraform output -raw ssh_command)"
    eval $SSH_COMMAND
```

When done with testing, you can destroy the resources with the following command:

```bash
    terraform destroy -auto-approve
```

For quick test cycles, use this command:

```bash
    terraform destroy -auto-approve && terraform apply -auto-approve
```