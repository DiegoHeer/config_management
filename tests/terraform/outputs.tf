output "ssh_access" {
  description = "Command to SSH to the test server"
  value       = "sshpass -p ${var.ansible_password} ssh ${var.ansible_username}@${var.ansible_host} -p ${var.ansible_port}"
}