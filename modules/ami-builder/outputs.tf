output "builder_instance_id" {
  description = "ID of the temporary AMI builder EC2"
  value       = aws_instance.builder.id
}

output "builder_public_ip" {
  description = "Public IP of the temporary builder"
  value       = aws_instance.builder.public_ip
}