variable "ssh_key_pair_name" {
  description = "ssh key pair name"
  default     = "id_ed25519"
  type        = string
}

variable "ssh_key_path" {
  description = "ssh key file path"
  default     = "~/.ssh/id_ed25519"
  type        = string
}