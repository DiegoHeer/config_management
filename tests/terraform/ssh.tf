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

resource "aws_key_pair" "ssh-key" {
  key_name   = var.ssh_key_pair_name
  public_key = file("${var.ssh_key_path}.pub")

  lifecycle {
    ignore_changes = [key_name]
  }
}
