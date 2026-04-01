output "bastion_public_ip" {
  value = aws_instance.bastion.public_ip
}

output "private_instance_ips" {
  value = aws_instance.private[*].private_ip
}

output "monitoring_private_ip" {
  value = aws_instance.monitoring.private_ip
}
