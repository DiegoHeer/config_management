# Configuration tests

The configuration management created can be tested on EC2 instances.
To provision the resources required for testing, please run (in this folder):

```bash
    terraform apply
```

Ssh into the machine to check if everything is according to expectations:

```bash
    IP_ADDRESS="$(terraform output -raw test_machine_ip_address)"
    ssh -i ./keys/ssh-key.pem ubuntu@$IP_ADDRESS
```

When done with testing, destroy the resources to avoid additional AWS costs:

```bash
    terraform destroy
```