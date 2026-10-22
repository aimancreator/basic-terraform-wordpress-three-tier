
variable "ami_id" {
  description = "Base Amazon Linux 2023 AMI ID"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type for the temporary builder"
  type        = string
  default     = "t3.micro"
}

variable "subnet_id" {
  description = "Public subnet for the temporary builder"
  type        = string
}

variable "security_group_id" {
  description = "Security group for the temporary builder"
  type        = string
}

variable "instance_profile_name" {
  description = "IAM instance profile for SSM access"
  type        = string
}
