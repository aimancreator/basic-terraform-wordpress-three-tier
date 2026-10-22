
output "endpoint_ids" {
  value = {
    for name, endpoint in aws_vpc_endpoint.ssm :
    name => endpoint.id
  }
}
