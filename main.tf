# Select an official, standard (non-minimal) Amazon Linux 2023 x86_64 image.
data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-kernel-*-x86_64"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }

  filter {
    name   = "state"
    values = ["available"]
  }
}

module "vpc" {
  source = "./modules/vpc"

  vpc_name = "wordpress-lab-vpc"
  vpc_cidr = "10.0.0.0/16"
}

module "security_groups" {
  source = "./modules/security-groups"

  vpc_id = module.vpc.vpc_id
}

module "iam" {
  source        = "./modules/iam"
  db_secret_arn = module.rds.db_secret_arn
}

module "ec2" {
  source = "./modules/ec2"

  ami_id                = data.aws_ami.amazon_linux_2023.id
  instance_type         = "t3.micro"
  subnet_id             = module.vpc.private_app_subnet_id
  security_group_id     = module.security_groups.ec2_sg_id
  instance_profile_name = module.iam.instance_profile_name

  aws_region    = var.aws_region
  db_endpoint   = module.rds.db_endpoint
  db_secret_arn = module.rds.db_secret_arn

  depends_on = [
    module.iam,
    module.security_groups,
    module.vpc_endpoints
  ]
}

module "vpc_endpoints" {
  source = "./modules/vpc-endpoints"

  vpc_id            = module.vpc.vpc_id
  subnet_id         = module.vpc.private_app_subnet_id
  security_group_id = module.security_groups.ssm_endpoint_sg_id
  aws_region        = var.aws_region
  depends_on        = [module.vpc]
}

module "rds" {
  source = "./modules/rds"

  db_subnet_ids     = module.vpc.db_subnet_ids
  security_group_id = module.security_groups.rds_sg_id
  db_username       = "admin"
}

module "alb" {
  source = "./modules/alb"

  vpc_id            = module.vpc.vpc_id
  public_subnet_ids = module.vpc.public_subnet_ids
  security_group_id = module.security_groups.alb_sg_id
  ec2_instance_id   = module.ec2.instance_id
}
