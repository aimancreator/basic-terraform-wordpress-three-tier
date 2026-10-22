output "wordpress_url" {
  description = "Open this URL after EC2 finishes installing WordPress."
  value       = "http://${module.alb.alb_dns_name}"
}

output "instance_id" {
  description = "WordPress EC2 instance ID for troubleshooting."
  value       = module.ec2.instance_id
}

output "ami_id" {
  description = "Official Amazon Linux 2023 image selected for this deployment."
  value       = data.aws_ami.amazon_linux_2023.id
}
