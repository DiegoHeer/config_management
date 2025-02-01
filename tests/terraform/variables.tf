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

variable "control_username" {
  description = "user name of current control node"
  default     = "diego"
  type        = string
}

variable "username" {
  description = "user name of new host node (server)"
  default     = "diego"
  type        = string
}