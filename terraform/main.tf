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

# 6 private ec2 instances using custom packer ami
resource "aws_instance" "private" {
  count                  = 6
  ami                    = var.ami_id
  instance_type          = "t2.micro"
  subnet_id              = module.vpc.private_subnet_ids[count.index % length(module.vpc.private_subnet_ids)]
  vpc_security_group_ids = [aws_security_group.private.id]
  key_name               = aws_key_pair.deployer.key_name

  tags = { Name = "hw8-private-${count.index}" }
}
