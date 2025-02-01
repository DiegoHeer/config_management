locals {
  name   = "config-management-test-setup"
  region = "eu-central-1"

  server_name = "config management test server"
  application = "home server config managment"
  environment = "config_management-test-env"
}

provider "aws" {
  region = local.region

  default_tags {
    tags = {
      Environment = local.environment
      Provisioned = "Terraform"
    }
  }
}

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_instance" "test_machine" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t2.micro"

  subnet_id                   = aws_subnet.public_subnet.id
  vpc_security_group_ids      = [aws_security_group.vpc.id, aws_security_group.ssh_access.id]
  associate_public_ip_address = true

  key_name = aws_key_pair.ssh-key.key_name

  root_block_device {
    volume_size = 12
  }

  tags = {
    Name = local.server_name
    App  = local.application
  }
}
