output "bastion_public_ip" {
  value = aws_instance.bastion.public_ip
}

output "ansible_controller_public_ip" {
  value = aws_instance.ansible_controller.public_ip
}

output "amazon_instance_ips" {
  value = aws_instance.private_amazon[*].private_ip
}

output "ubuntu_instance_ips" {
  value = aws_instance.private_ubuntu[*].private_ip
}
