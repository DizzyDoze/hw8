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
  ami_name      = "custom-docker-monitoring-ami-{{timestamp}}"
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

  # install node exporter for prometheus metrics
  provisioner "shell" {
    inline = [
      "wget https://github.com/prometheus/node_exporter/releases/download/v1.8.2/node_exporter-1.8.2.linux-amd64.tar.gz",
      "tar xzf node_exporter-1.8.2.linux-amd64.tar.gz",
      "sudo mv node_exporter-1.8.2.linux-amd64/node_exporter /usr/local/bin/",
      "rm -rf node_exporter-1.8.2.linux-amd64*",
      "sudo useradd --no-create-home --shell /bin/false node_exporter",
      "sudo tee /etc/systemd/system/node_exporter.service > /dev/null <<'EOF'\n[Unit]\nDescription=Node Exporter\nAfter=network.target\n\n[Service]\nUser=node_exporter\nExecStart=/usr/local/bin/node_exporter\n\n[Install]\nWantedBy=multi-user.target\nEOF",
      "sudo systemctl daemon-reload",
      "sudo systemctl enable node_exporter"
    ]
  }

  provisioner "shell" {
    inline = [
      "echo '${file(pathexpand(var.ssh_public_key))}' >> /home/ec2-user/.ssh/authorized_keys"
    ]
  }
}
