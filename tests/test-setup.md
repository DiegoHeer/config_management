# Configuration tests

The configuration management created can be tested on EC2 instances.
To provision the resources required for testing, please run (in terraform folder):

```bash
    terraform apply -auto-approve
```

To test a specific playbook, run the following command (note that a new inventory.yml is created, and that there already should be an `vault_key` file in the root directory with the vault password):

```bash
    poetry run ansible-playbook tests/<TEST FILE>.yml -i tests/inventory.yml --vault-password-file vault_key
```

Ssh into the machine to check if everything is according to expectations:

```bash
    SSH_COMMAND="$(terraform output -raw ssh_command)"
    eval $SSH_COMMAND
```

When done with testing, destroy the resources to avoid additional AWS costs:

```bash
    terraform destroy -auto-approve
```