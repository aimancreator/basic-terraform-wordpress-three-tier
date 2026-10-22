
output "alb_sg_id" {
  value = aws_security_group.this["alb"].id
}

output "ec2_sg_id" {
  value = aws_security_group.this["ec2"].id
}

output "rds_sg_id" {
  value = aws_security_group.this["rds"].id
}


output "ssm_endpoint_sg_id" {
  value = aws_security_group.this["ssm_endpoint"].id
}

output "ami_builder_sg_id" {
  value = aws_security_group.ami_builder.id
}