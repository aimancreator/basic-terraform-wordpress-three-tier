
locals {
  security_groups = {
    alb = {
      name        = "wordpress-alb-sg"
      description = "Security group for Application Load Balancer"
    }

    ec2 = {
      name        = "wordpress-ec2-sg"
      description = "Security group for WordPress EC2"
    }

    rds = {
      name        = "wordpress-rds-sg"
      description = "Security group for MySQL RDS"
    }
    ssm_endpoint = {
      name        = "wordpress-ssm-endpoint-sg"
      description = "Security group for SSM VPC endpoints"
    }
  }
}

resource "aws_security_group" "this" {
  for_each = local.security_groups

  name        = each.value.name
  description = each.value.description
  vpc_id      = var.vpc_id

  tags = {
    Name = each.value.name
  }
}



locals {
  ingress_rules = {
    alb_http = {
      target = "alb"
      source = null
      cidr   = "0.0.0.0/0"
      port   = 80
    }

    ec2_http = {
      target = "ec2"
      source = "alb"
      cidr   = null
      port   = 80
    }

    rds_mysql = {
      target = "rds"
      source = "ec2"
      cidr   = null
      port   = 3306
    }


    ssm_https = {
      target = "ssm_endpoint"
      source = "ec2"
      cidr   = null
      port   = 443
    }

  }
}

resource "aws_vpc_security_group_ingress_rule" "this" {
  for_each = local.ingress_rules

  security_group_id = aws_security_group.this[each.value.target].id

  cidr_ipv4 = each.value.cidr

  referenced_security_group_id = (
    each.value.source == null
    ? null
    : aws_security_group.this[each.value.source].id
  )

  ip_protocol = "tcp"
  from_port   = each.value.port
  to_port     = each.value.port

  tags = {
    Name = each.key
  }
}



locals {
  egress_rules = {
    alb_to_ec2 = {
      source = "alb"
      target = "ec2"
      port   = 80
    }

    ec2_to_rds = {
      source = "ec2"
      target = "rds"
      port   = 3306
    }
    ec2_to_ssm = {
      source = "ec2"
      target = "ssm_endpoint"
      port   = 443
    }

  }
}

resource "aws_vpc_security_group_egress_rule" "this" {
  for_each = local.egress_rules

  security_group_id = aws_security_group.this[each.value.source].id

  referenced_security_group_id = aws_security_group.this[each.value.target].id

  ip_protocol = "tcp"
  from_port   = each.value.port
  to_port     = each.value.port

  tags = {
    Name = each.key
  }
}


resource "aws_security_group" "ami_builder" {
  name        = "wordpress-ami-builder-sg"
  description = "Outbound internet access for AMI builder"
  vpc_id      = var.vpc_id

  tags = {
    Name = "wordpress-ami-builder-sg"
  }
}

resource "aws_vpc_security_group_egress_rule" "ami_builder_https" {
  security_group_id = aws_security_group.ami_builder.id

  cidr_ipv4   = "0.0.0.0/0"
  ip_protocol = "tcp"
  from_port   = 443
  to_port     = 443
}

resource "aws_vpc_security_group_egress_rule" "ami_builder_http" {
  security_group_id = aws_security_group.ami_builder.id

  cidr_ipv4   = "0.0.0.0/0"
  ip_protocol = "tcp"
  from_port   = 80
  to_port     = 80
}

# Package repositories and WordPress downloads use the NAT gateway.
resource "aws_vpc_security_group_egress_rule" "ec2_web" {
  for_each = toset(["80", "443"])

  security_group_id = aws_security_group.this["ec2"].id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "tcp"
  from_port         = tonumber(each.key)
  to_port           = tonumber(each.key)
}
