output "test_machine_ip_address" {
  description = "Public IP address of the test machine EC2 instance"
  value       = aws_instance.test_machine.public_ip
}
