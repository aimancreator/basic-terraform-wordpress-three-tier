
output "instance_id" {
  value = aws_instance.wordpress.id
}

output "private_ip" {
  value = aws_instance.wordpress.private_ip
}
