# HW8 - Packer & Terraform

Custom AWS AMI built with Packer (Amazon Linux 2023 + Docker), deployed with Terraform into a VPC with a bastion host and 6 private instances.

## Architecture

- VPC (`10.0.0.0/16`) with 2 public and 2 private subnets across 2 AZs
- Internet Gateway for public subnets, NAT Gateway for private subnets
- Bastion host in public subnet (SSH restricted to my IP only)
- 6 private EC2 instances using the custom Packer AMI (Docker pre-installed)
- SSH access to private instances via bastion using agent forwarding

## Prerequisites

- AWS CLI configured with credentials
- Terraform
- Packer
- SSH key pair (`~/.ssh/id_ed25519`)

## Build the AMI

```bash
cd packer
packer init .
packer build ami.pkr.hcl
```

Copy the AMI ID from the output.

## Deploy Infrastructure

Update `terraform/terraform.tfvars` with your values:

```hcl
region = "us-west-2"
my_ip  = "YOUR.PUBLIC.IP/32"
ami_id = "ami-xxxxxxxxxxxxxxxxx"
```

Then:

```bash
cd terraform
terraform init
terraform plan
terraform apply
```

## Connect to Private Instances

```bash
# start ssh agent and add key
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/id_ed25519

# ssh to bastion with agent forwarding
ssh -A ec2-user@<BASTION_PUBLIC_IP>

# from bastion, hop to any private instance
ssh ec2-user@<PRIVATE_INSTANCE_IP>

# verify docker
docker --version
```

## Tear Down

```bash
cd terraform
terraform destroy
```

Then deregister the AMI and delete its snapshot in AWS Console.

## Project Structure

```
hw8/
├── packer/
│   └── ami.pkr.hcl              # packer template: amazon linux 2023 + docker + ssh key
├── terraform/
│   ├── main.tf                  # provider, security groups, bastion, 6 private instances
│   ├── variables.tf             # region, my_ip, ami_id, ssh key path
│   ├── outputs.tf               # bastion public ip, private instance ips
│   ├── terraform.tfvars         # actual values (git-ignored)
│   └── modules/
│       └── vpc/
│           ├── main.tf          # vpc, subnets, igw, nat gw, route tables
│           ├── variables.tf     # vpc_cidr, subnet cidrs, availability zones
│           └── outputs.tf       # vpc_id, subnet ids
└── README.md
```
