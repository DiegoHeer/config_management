output "root_ssh_access" {
  description = "Command to SSH using root user to the test server"
  value = "sshpass -p ${var.ansible_password} ssh ${var.ansible_username}@${var.ansible_host} -p ${var.ansible_port}"
}

output "local_ssh_access" {
  description = "Command to SSH using local user to the test server"
  value       = "ssh ${var.username}@${var.ansible_host} -p ${var.ansible_port}"
}
