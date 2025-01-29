variable "ssh_key_pair_name" {
  description = "ssh key pair name"
  default     = "ssh-key"
  type        = string
}

variable "ssh_file_name" {
  description = "Name of the ssh key pair file"
  default     = "./keys/ssh-key.pem"
  type        = string
}