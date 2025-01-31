# Configuration tests

The configuration management created can be tested on EC2 instances.
To provision the resources required for testing, please run (in terraform folder):

```bash
    terraform apply
```

Ssh into the machine to check if everything is according to expectations:

```bash
    SSH_COMMAND="$(terraform output -raw ssh_command)"
    eval $SSH_COMMAND
```

When done with testing, destroy the resources to avoid additional AWS costs:

```bash
    terraform destroy
```