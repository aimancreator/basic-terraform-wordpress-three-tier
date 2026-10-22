
variable "db_subnet_ids" {
  type = list(string)
}

variable "security_group_id" {
  type = string
}

variable "db_username" {
  type    = string
  default = "admin"
}
