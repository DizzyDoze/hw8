provider "aws" {
  region = var.region
}

# vpc with public and private subnets
module "vpc" {
  source = "./modules/vpc"

  vpc_cidr             = "10.0.0.0/16"
  public_subnet_cidrs  = ["10.0.1.0/24", "10.0.2.0/24"]
  private_subnet_cidrs = ["10.0.3.0/24", "10.0.4.0/24"]
  availability_zones   = ["${var.region}a", "${var.region}b"]
}

# upload ssh public key to aws
resource "aws_key_pair" "deployer" {
  key_name   = "hw8-deployer-key"
  public_key = file(pathexpand(var.ssh_public_key_path))
}

# bastion sg: only allow ssh from my ip
resource "aws_security_group" "bastion" {
  name   = "hw8-bastion-sg"
  vpc_id = module.vpc.vpc_id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.my_ip]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# private sg: only allow ssh from bastion
resource "aws_security_group" "private" {
  name   = "hw8-private-sg"
  vpc_id = module.vpc.vpc_id

  ingress {
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# latest amazon linux 2023 for bastion (no need for custom ami)
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}


# bastion host in public subnet
resource "aws_instance" "bastion" {
  ami                         = data.aws_ami.amazon_linux.id
  instance_type               = "t2.micro"
  subnet_id                   = module.vpc.public_subnet_ids[0]
  vpc_security_group_ids      = [aws_security_group.bastion.id]
  key_name                    = aws_key_pair.deployer.key_name
  associate_public_ip_address = true

  tags = { Name = "hw8-bastion" }
}

# 3 Amazon Linux EC2 instances (private subnet)
resource "aws_instance" "private_amazon" {
  count                  = 3
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = "t2.micro"
  subnet_id              = module.vpc.private_subnet_ids[count.index % length(module.vpc.private_subnet_ids)]
  vpc_security_group_ids = [aws_security_group.private.id]
  key_name               = aws_key_pair.deployer.key_name

  tags = {
    Name = "hw11-amazon-${count.index}"
    OS   = "amazon"
  }
}

# 3 Ubuntu EC2 instances (private subnet)
resource "aws_instance" "private_ubuntu" {
  count                  = 3
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t2.micro"
  subnet_id              = module.vpc.private_subnet_ids[count.index % length(module.vpc.private_subnet_ids)]
  vpc_security_group_ids = [aws_security_group.private.id]
  key_name               = aws_key_pair.deployer.key_name

  tags = {
    Name = "hw11-ubuntu-${count.index}"
    OS   = "ubuntu"
  }
}

# Ansible Controller (public subnet)
resource "aws_instance" "ansible_controller" {
  ami                         = data.aws_ami.amazon_linux.id
  instance_type               = "t2.micro"
  subnet_id                   = module.vpc.public_subnet_ids[1]
  vpc_security_group_ids      = [aws_security_group.bastion.id]
  key_name                    = aws_key_pair.deployer.key_name
  associate_public_ip_address = true

  tags = { Name = "hw11-ansible-controller" }
}
