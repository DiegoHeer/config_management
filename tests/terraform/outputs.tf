output "test_machine_ip_address" {
  description = "Public IP address of the test machine EC2 instance"
  value       = aws_instance.test_machine.public_ip
}

output "ssh_command" {
  description = "SSH command to access the newly created EC2 instance"
  value       = "ssh -i ${var.ssh_key_path} ubuntu@${aws_instance.test_machine.public_ip}"
}