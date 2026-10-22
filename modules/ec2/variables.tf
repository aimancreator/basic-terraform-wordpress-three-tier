
variable "subnet_id" {
  type = string
}

variable "security_group_id" {
  type = string
}

variable "instance_profile_name" {
  type = string
}

variable "instance_type" {
  type    = string
  default = "t3.micro"
}

variable "ami_id" {
  type = string
}

variable "db_endpoint" {
  description = "RDS MySQL endpoint"
  type        = string
}

variable "db_secret_arn" {
  description = "ARN of the RDS credentials in Secrets Manager"
  type        = string
}
variable "aws_region" {
  description = "Region containing the RDS-managed secret."
  type        = string
}
