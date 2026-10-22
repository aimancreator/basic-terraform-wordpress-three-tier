
output "db_endpoint" {
  value = aws_db_instance.wordpress.endpoint
}

output "db_name" {
  value = aws_db_instance.wordpress.db_name
}

output "db_secret_arn" {
  value = aws_db_instance.wordpress.master_user_secret[0].secret_arn
}
