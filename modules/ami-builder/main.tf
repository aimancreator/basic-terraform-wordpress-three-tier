
resource "aws_instance" "builder" {
  ami           = var.ami_id
  instance_type = var.instance_type

  subnet_id              = var.subnet_id
  vpc_security_group_ids = [var.security_group_id]

  associate_public_ip_address = true
  iam_instance_profile        = var.instance_profile_name

  root_block_device {
    volume_type = "gp3"
    volume_size = 20
  }

  tags = {
    Name = "wordpress-ami-builder"
  }

  user_data = templatefile("${path.module}/install-wordpress.sh", {
    verification_script = file("${path.module}/verify-wordpress.sh")
  })


}
