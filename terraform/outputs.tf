output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.main.id
}

output "bastion_public_ip" {
  description = "Public IP of the bastion host"
  value       = aws_eip.bastion.public_ip
}

output "backend_private_ip" {
  description = "Private IP of the backend server"
  value       = aws_instance.backend.private_ip
}

output "mongodb_private_ip" {
  description = "Private IP of the MongoDB server"
  value       = aws_instance.mongodb.private_ip
}

output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer"
  value       = aws_lb.main.dns_name
}