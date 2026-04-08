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
<img width="1250" height="658" alt="Screenshot 2026-04-07 at 11 17 12 PM" src="https://github.com/user-attachments/assets/f95dfca2-1fe0-4336-b9fc-1051836add63" />


Forward the Key and jump to the private subnet:

```bash
ssh -A -i ~/.ssh/id_ed25519 ec2-user@<ansible_controller_public_ip> 
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

Copy `ansible/playbook.yml` to the controller:
```bash
scp -i ~/.ssh/id_ed25519 ansible/playbook.yml ansible/inventory.ini ec2-user@<ansible_controller_public_ip>:~/
```
<img width="1249" height="77" alt="Screenshot 2026-04-07 at 11 17 47 PM" src="https://github.com/user-attachments/assets/9fea20a2-7e69-4586-aa96-7bdfdb43fe0c" />


Then run:
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
