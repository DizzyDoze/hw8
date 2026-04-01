# prometheus + grafana monitoring instance in private subnet
resource "aws_instance" "monitoring" {
  ami                    = var.ami_id
  instance_type          = "t2.micro"
  subnet_id              = module.vpc.private_subnet_ids[0]
  vpc_security_group_ids = [aws_security_group.monitoring.id]
  key_name               = aws_key_pair.deployer.key_name

  user_data = base64encode(templatefile("${path.module}/templates/monitoring-userdata.sh.tpl", {
    private_ips                    = aws_instance.private[*].private_ip
    grafana_dashboard_provider_yml = file("${path.module}/templates/grafana-dashboard-provider.yml")
    grafana_dashboard_json         = file("${path.module}/templates/grafana-dashboard.json")
  }))

  tags = { Name = "hw8-monitoring" }
}
