
resource "aws_instance" "wordpress" {
  ami                    = var.ami_id
  instance_type          = var.instance_type
  subnet_id              = var.subnet_id
  vpc_security_group_ids = [var.security_group_id]
  iam_instance_profile   = var.instance_profile_name

  associate_public_ip_address = false

  user_data_replace_on_change = true

  user_data = templatefile("${path.module}/configure-wordpress.sh", {
    aws_region    = var.aws_region
    db_endpoint   = var.db_endpoint
    db_secret_arn = var.db_secret_arn
  })

  root_block_device {
    volume_type = "gp3"
    volume_size = 20
  }

  tags = {
    Name = "wordpress-private-ec2"
  }
}
