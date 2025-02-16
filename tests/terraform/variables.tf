variable "ansible_host" {
  description = "IP host that Ansible can use to SSH to the test server"
  default     = "localhost"
  type        = string
}
variable "ansible_port" {
  description = "IP port that Ansible can use to SSH to the test server"
  default     = 2222
  type        = number
}

variable "ansible_username" {
  description = "User name that Ansible can use to SSH to the test server"
  default     = "root"
  type        = string
}

variable "ansible_password" {
  description = "User password that Ansible can use to SSH to the test server"
  default     = "ubuntu"
  type        = string
}
