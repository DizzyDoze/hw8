# aws ebs builder, launch temp EC2 instance from official Amazon Linux AMI
# plugin for amazon
packer {
  required_plugins {
    amazon = {
      source  = "github.com/hashicorp/amazon"
      version = "~> 1"
    }
  }
}

# ssh public key to bake into the AMI, directly look into local files
variable "ssh_public_key" {
  type    = string
  default = "~/.ssh/id_ed25519.pub"
}

# base image and instance config
source "amazon-ebs" "amazon-linux" {
  ami_name      = "custom-docker-ami-{{timestamp}}"
  instance_type = "t2.micro"
  region        = "us-west-2"
  ssh_username  = "ec2-user"

  # latest amazon linux 2023
  source_ami_filter {
    filters = {
      name                = "al2023-ami-*-x86_64"
      root-device-type    = "ebs"
      virtualization-type = "hvm"
    }
    most_recent = true
    owners      = ["amazon"]
  }
}

# install docker and inject ssh key
build {
  sources = ["source.amazon-ebs.amazon-linux"]

  provisioner "shell" {
    inline = [
      "sudo dnf update -y",
      "sudo dnf install -y docker",
      "sudo systemctl enable docker",
      "sudo systemctl start docker",
      "sudo usermod -aG docker ec2-user"
    ]
  }

  provisioner "shell" {
    inline = [
      "echo '${file(pathexpand(var.ssh_public_key))}' >> /home/ec2-user/.ssh/authorized_keys"
    ]
  }
}
