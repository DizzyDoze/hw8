variable "region" {
  type = string
}

variable "my_ip" {
  type = string
}

variable "ami_id" {
  type = string
}

variable "ssh_public_key_path" {
  type    = string
  default = "~/.ssh/id_ed25519.pub"
}
