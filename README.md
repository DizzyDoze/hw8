# HW8 - Packer, Terraform, Prometheus & Grafana

Custom AWS AMI built with Packer (Amazon Linux 2023 + Docker + Node Exporter), deployed with Terraform into a VPC with a bastion host, 6 private instances, and a monitoring instance running Prometheus and Grafana.

## Architecture

- VPC (`10.0.0.0/16`) with 2 public and 2 private subnets across 2 AZs
- Internet Gateway for public subnets, NAT Gateway for private subnets
- Bastion host in public subnet (SSH restricted to my IP only)
- 6 private EC2 instances using the custom Packer AMI (Docker + Node Exporter pre-installed)
- 1 monitoring EC2 instance in private subnet running Prometheus and Grafana via Docker
- Node Exporter on all private instances exposes metrics on port 9100
- Prometheus scrapes all instances and Grafana visualizes the data
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

Terraform will output:
- `bastion_public_ip` — public IP of the bastion host
- `private_instance_ips` — list of 6 private instance IPs
- `monitoring_private_ip` — private IP of the Prometheus/Grafana instance

## Connect to Private Instances

```bash
# start ssh agent and add key
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/id_ed25519

# ssh to bastion with agent forwarding
ssh -A ec2-user@<BASTION_PUBLIC_IP>

# from bastion, hop to any private instance
ssh ec2-user@<PRIVATE_INSTANCE_IP>

# verify docker and node exporter
docker --version
curl localhost:9100/metrics
```

## Access Prometheus

Use SSH tunneling through the bastion to access Prometheus from your local machine:

```bash
ssh -A -L 9090:<MONITORING_PRIVATE_IP>:9090 ec2-user@<BASTION_PUBLIC_IP>
```

Then open http://localhost:9090 in your browser.

- Go to **Status > Targets** to verify all instances are being scraped
- Try a query like `up` to see all targets or `node_cpu_seconds_total` for CPU metrics

## Access Grafana

Use SSH tunneling through the bastion:

```bash
ssh -A -L 3000:<MONITORING_PRIVATE_IP>:3000 ec2-user@<BASTION_PUBLIC_IP>
```

Then open http://localhost:3000 in your browser.

- **Login**: admin / admin
- A pre-configured dashboard "Node Exporter - CPU & Memory" is automatically provisioned
- The dashboard shows CPU utilization and memory utilization for each EC2 instance

## Screenshots

### Prometheus Targets
![Prometheus Targets](screenshots/prometheus-targets.png)

### Grafana Dashboard
![Grafana Dashboard](screenshots/grafana-dashboard.png)

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
│   └── ami.pkr.hcl                          # packer template: amazon linux 2023 + docker + node exporter + ssh key
├── terraform/
│   ├── main.tf                              # provider, security groups, bastion, 6 private instances
│   ├── monitoring.tf                        # prometheus + grafana monitoring instance
│   ├── variables.tf                         # region, my_ip, ami_id, ssh key path
│   ├── outputs.tf                           # bastion ip, private ips, monitoring ip
│   ├── terraform.tfvars                     # actual values (git-ignored)
│   ├── templates/
│   │   ├── monitoring-userdata.sh.tpl       # user_data script for prometheus + grafana setup
│   │   ├── grafana-datasource.yml           # grafana auto-provisioned prometheus datasource
│   │   ├── grafana-dashboard-provider.yml   # grafana dashboard file provider config
│   │   └── grafana-dashboard.json           # pre-built CPU & memory dashboard
│   └── modules/
│       └── vpc/
│           ├── main.tf                      # vpc, subnets, igw, nat gw, route tables
│           ├── variables.tf                 # vpc_cidr, subnet cidrs, availability zones
│           └── outputs.tf                   # vpc_id, subnet ids
└── README.md
```
