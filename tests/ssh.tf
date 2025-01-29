resource "aws_security_group" "ssh_access" {
  name   = "allow-ssh-access"
  vpc_id = aws_vpc.vpc.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "tls_private_key" "rsa-key" {
  algorithm = "RSA"
}

resource "aws_key_pair" "ssh-key" {
  key_name   = var.ssh_key_pair_name
  public_key = tls_private_key.rsa-key.public_key_openssh

  lifecycle {
    ignore_changes = [key_name]
  }
}

resource "local_file" "ssh-key" {
  content  = tls_private_key.rsa-key.private_key_pem
  filename = var.ssh_file_name
}