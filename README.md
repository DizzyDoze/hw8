# HW11 - Terraform + Ansible

Provisions 7 EC2 instances on AWS using Terraform (with modules), then uses Ansible to update packages, ensure the latest Docker is installed, and report disk usage on all 6 target instances.

## Architecture

- VPC (`10.0.0.0/16`) with 2 public and 2 private subnets across 2 AZs
- Internet Gateway for public subnets, NAT Gateway for private subnets
- **Bastion host** in public subnet (SSH restricted to your IP)
- **Ansible Controller** in public subnet (used to run playbooks against private instances)
- **3 Amazon Linux** EC2 instances in private subnets — tagged `OS: amazon`
- **3 Ubuntu** EC2 instances in private subnets — tagged `OS: ubuntu`
- Security groups allow the Ansible Controller to SSH into all private instances

## Prerequisites

- AWS CLI configured (`aws configure`)
- Terraform >= 1.0
- SSH key pair at `~/.ssh/id_ed25519` (or update `ssh_public_key_path` in `terraform.tfvars`)

## 1. Deploy Infrastructure

Edit `terraform/terraform.tfvars` with your values:

```hcl
region = "us-west-2"
my_ip  = "YOUR.PUBLIC.IP/32"
```

Then apply:

```bash
cd terraform
terraform init
terraform plan
terraform apply
```

Note the output — you will need these IPs in the next steps:

```
ansible_controller_public_ip = "..."
amazon_instance_ips = [...]
ubuntu_instance_ips = [...]
```

## 2. Set Up the Ansible Controller

SSH into the Ansible Controller:

```bash
ssh -i ~/.ssh/id_ed25519 ec2-user@<ansible_controller_public_ip>
```

Install Ansible:

```bash
sudo dnf install -y ansible
```

Copy your SSH private key to the controller (from your local machine):

```bash
scp -i ~/.ssh/id_ed25519 ~/.ssh/id_ed25519 ec2-user@<ansible_controller_public_ip>:~/.ssh/id_ed25519
chmod 600 ~/.ssh/id_ed25519   # run this on the controller
```

## 3. Update the Inventory

On the Ansible Controller, create `inventory.ini` using the IPs from `terraform output`:

```ini
[amazon]
<amazon_ip_1> ansible_user=ec2-user
<amazon_ip_2> ansible_user=ec2-user
<amazon_ip_3> ansible_user=ec2-user

[ubuntu]
<ubuntu_ip_1> ansible_user=ubuntu
<ubuntu_ip_2> ansible_user=ubuntu
<ubuntu_ip_3> ansible_user=ubuntu

[all:vars]
ansible_ssh_private_key_file=~/.ssh/id_ed25519
ansible_ssh_common_args='-o StrictHostKeyChecking=no'
```

## 4. Run the Playbook

Copy `ansible/playbook.yml` to the controller and run:

```bash
ansible-playbook -i inventory.ini playbook.yml
```

The playbook will:
- Update and upgrade all packages (via `dnf` on Amazon Linux, `apt` on Ubuntu)
- Install/upgrade Docker to the latest version
- Start and enable the Docker service
- Report the Docker version on each instance
- Report disk usage (`df -h`) on each instance

## 5. Tear Down

```bash
cd terraform
terraform destroy
```

## Project Structure

```
hw11/
├── ansible/
│   ├── inventory.ini       # static inventory (update IPs after terraform apply)
│   └── playbook.yml        # update packages, ensure latest docker, report disk usage
├── terraform/
│   ├── main.tf             # provider, security groups, bastion, ansible controller, 6 EC2s
│   ├── variables.tf
│   ├── outputs.tf
│   ├── terraform.tfvars    # region, my_ip
│   └── modules/
│       └── vpc/
│           ├── main.tf     # vpc, subnets, igw, nat gateway, route tables
│           ├── variables.tf
│           └── outputs.tf
└── README.md
```
