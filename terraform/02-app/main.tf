terraform {
  required_version = ">= 1.10.0"

  backend "s3" {}

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

variable "db_password" {
  type        = string
  description = "RDS MySQL password supplied by GitHub Actions secret DB_PASSWORD"
  sensitive   = true
}

locals {
  environment           = "sandbox"
  app_name              = "healthcare"
  vpc_cidr              = "10.20.0.0/16"
  public_subnet_a_cidr  = "10.20.1.0/24"
  public_subnet_b_cidr  = "10.20.2.0/24"
  private_subnet_a_cidr = "10.20.101.0/24"
  private_subnet_b_cidr = "10.20.102.0/24"

  ecr_repository_name = "customermanagementapp"

  container_port    = 3000
  health_check_path = "/"

  db_engine   = "mysql"
  db_name     = "healthcaredb"
  db_username = "admin"
  db_port     = 3306

  cloudfront_origin_id = "alb-origin"
  cognito_callback_url = "https://${aws_cloudfront_distribution.app.domain_name}/"
  cognito_logout_url   = "https://${aws_cloudfront_distribution.app.domain_name}/"

  common_tags = {
    Environment = local.environment
  }
}

data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

data "aws_ssm_parameter" "al2023_ami" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

data "aws_cloudfront_cache_policy" "caching_disabled" {
  name = "Managed-CachingDisabled"
}

data "aws_cloudfront_origin_request_policy" "all_viewer" {
  name = "Managed-AllViewer"
}

resource "aws_ecr_repository" "app" {
  name                 = local.ecr_repository_name
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }

  tags = merge(local.common_tags, {
    Name = local.ecr_repository_name
  })
}

resource "aws_vpc" "main" {
  cidr_block           = local.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = merge(local.common_tags, {
    Name = "HealthcareAppVPC"
  })
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = merge(local.common_tags, {
    Name = "internet gateway"
  })
}

resource "aws_subnet" "public_a" {
  vpc_id                  = aws_vpc.main.id
  availability_zone       = data.aws_availability_zones.available.names[0]
  cidr_block              = local.public_subnet_a_cidr
  map_public_ip_on_launch = true

  tags = merge(local.common_tags, {
    Name = "PublicSubnet-${data.aws_availability_zones.available.names[0]}"
  })
}

resource "aws_subnet" "public_b" {
  vpc_id                  = aws_vpc.main.id
  availability_zone       = data.aws_availability_zones.available.names[1]
  cidr_block              = local.public_subnet_b_cidr
  map_public_ip_on_launch = true

  tags = merge(local.common_tags, {
    Name = "PublicSubnet-${data.aws_availability_zones.available.names[1]}"
  })
}

resource "aws_subnet" "private_a" {
  vpc_id                  = aws_vpc.main.id
  availability_zone       = data.aws_availability_zones.available.names[0]
  cidr_block              = local.private_subnet_a_cidr
  map_public_ip_on_launch = false

  tags = merge(local.common_tags, {
    Name = "PrivateSubnet-${data.aws_availability_zones.available.names[0]}"
  })
}

resource "aws_subnet" "private_b" {
  vpc_id                  = aws_vpc.main.id
  availability_zone       = data.aws_availability_zones.available.names[1]
  cidr_block              = local.private_subnet_b_cidr
  map_public_ip_on_launch = false

  tags = merge(local.common_tags, {
    Name = "PrivateSubnet-${data.aws_availability_zones.available.names[1]}"
  })
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  tags = merge(local.common_tags, {
    Name = "PublicRouteTable"
  })
}

resource "aws_route" "public_internet" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.main.id
}

resource "aws_route_table_association" "public_a" {
  subnet_id      = aws_subnet.public_a.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public_b" {
  subnet_id      = aws_subnet.public_b.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  tags = merge(local.common_tags, {
    Name = "PrivateRouteTable"
  })
}

resource "aws_route_table_association" "private_a" {
  subnet_id      = aws_subnet.private_a.id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "private_b" {
  subnet_id      = aws_subnet.private_b.id
  route_table_id = aws_route_table.private.id
}

resource "aws_security_group" "alb" {
  name        = "healthcare-alb-sg"
  description = "Allow HTTP to ALB"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "HTTP from internet and CloudFront"
    protocol    = "tcp"
    from_port   = 80
    to_port     = 80
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name = "AlbSG"
  })
}

resource "aws_security_group" "ec2" {
  name        = "healthcare-ec2-ssm-sg"
  description = "EC2 SG for SSM access; no SSH required"
  vpc_id      = aws_vpc.main.id

  egress {
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name = "Ec2SsmSG"
  })
}

resource "aws_security_group" "rds" {
  name        = "healthcare-rds-sg"
  description = "Allow MySQL access from EC2 SSM instance"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "MySQL from EC2 SSM instance"
    protocol        = "tcp"
    from_port       = local.db_port
    to_port         = local.db_port
    security_groups = [aws_security_group.ec2.id]
  }

  egress {
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name = "RdsSG"
  })
}

resource "aws_db_subnet_group" "main" {
  name        = "healthcare-db-subnet-group"
  description = "Private subnets for RDS"
  subnet_ids   = [aws_subnet.private_a.id, aws_subnet.private_b.id]

  tags = local.common_tags
}

resource "aws_db_instance" "health" {
  identifier              = "db-health"
  instance_class          = "db.t3.micro"
  allocated_storage       = 20
  storage_type            = "gp2"
  engine                  = local.db_engine
  db_name                 = local.db_name
  username                = local.db_username
  password                = var.db_password
  port                    = local.db_port
  availability_zone       = data.aws_availability_zones.available.names[0]
  multi_az                = false
  publicly_accessible     = false
  backup_retention_period = 0
  deletion_protection     = false
  skip_final_snapshot     = true
  vpc_security_group_ids  = [aws_security_group.rds.id]
  db_subnet_group_name    = aws_db_subnet_group.main.name

  tags = merge(local.common_tags, {
    Name = "db-health"
  })
}

resource "aws_secretsmanager_secret" "db" {
  name                    = "db-health-connection-sandbox-01"
  description             = "RDS connection parameters for db-health sandbox"
  recovery_window_in_days = 0

  tags = local.common_tags
}

resource "aws_secretsmanager_secret_version" "db" {
  secret_id = aws_secretsmanager_secret.db.id

  secret_string = jsonencode({
    environment = local.environment
    engine      = local.db_engine
    host        = aws_db_instance.health.address
    port        = aws_db_instance.health.port
    dbname      = local.db_name
    username    = local.db_username
    password    = var.db_password
  })
}

resource "aws_lb" "main" {
  name               = "healthcare-alb"
  internal           = false
  load_balancer_type = "application"
  subnets            = [aws_subnet.public_a.id, aws_subnet.public_b.id]
  security_groups    = [aws_security_group.alb.id]

  tags = local.common_tags
}

resource "aws_lb_target_group" "app" {
  name        = "healthcare-tg"
  vpc_id      = aws_vpc.main.id
  target_type = "ip"
  port        = local.container_port
  protocol    = "HTTP"

  health_check {
    protocol = "HTTP"
    path     = local.health_check_path
    matcher  = "200-399"
  }

  tags = local.common_tags
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }
}

resource "aws_cloudfront_distribution" "app" {
  enabled         = true
  is_ipv6_enabled = true
  comment         = "CloudFront distribution for ${local.app_name} ${local.environment}"
  price_class     = "PriceClass_100"

  origin {
    domain_name = aws_lb.main.dns_name
    origin_id   = local.cloudfront_origin_id

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "http-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  default_cache_behavior {
    target_origin_id       = local.cloudfront_origin_id
    viewer_protocol_policy = "redirect-to-https"

    allowed_methods = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods  = ["GET", "HEAD"]

    cache_policy_id          = data.aws_cloudfront_cache_policy.caching_disabled.id
    origin_request_policy_id = data.aws_cloudfront_origin_request_policy.all_viewer.id
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }

  depends_on = [
    aws_lb_listener.http
  ]

  tags = local.common_tags
}

resource "aws_cognito_user_pool" "app" {
  name = "${local.app_name}-${local.environment}-user-pool"

  username_attributes      = ["email"]
  auto_verified_attributes = ["email"]
  mfa_configuration        = "OFF"

  admin_create_user_config {
    allow_admin_create_user_only = true
  }

  account_recovery_setting {
    recovery_mechanism {
      name     = "verified_email"
      priority = 1
    }
  }

  password_policy {
    minimum_length                   = 8
    require_lowercase                = true
    require_numbers                  = true
    require_symbols                  = false
    require_uppercase                = true
    temporary_password_validity_days = 7
  }

  schema {
    name                = "email"
    attribute_data_type = "String"
    mutable             = true
    required            = true

    string_attribute_constraints {
      min_length = 5
      max_length = 2048
    }
  }

  tags = local.common_tags
}

resource "aws_cognito_user_pool_client" "web" {
  name         = "${local.app_name}-${local.environment}-web-client"
  user_pool_id = aws_cognito_user_pool.app.id

  generate_secret                      = false
  supported_identity_providers         = ["COGNITO"]
  allowed_oauth_flows_user_pool_client = true
  allowed_oauth_flows                  = ["code"]
  allowed_oauth_scopes                 = ["email", "openid", "profile"]
  callback_urls                        = [local.cognito_callback_url]
  logout_urls                          = [local.cognito_logout_url]

  explicit_auth_flows = [
    "ALLOW_REFRESH_TOKEN_AUTH",
    "ALLOW_USER_PASSWORD_AUTH",
    "ALLOW_USER_SRP_AUTH"
  ]

  prevent_user_existence_errors = "ENABLED"
}

resource "aws_cognito_user_pool_domain" "main" {
  domain       = "${local.app_name}-${local.environment}-${data.aws_caller_identity.current.account_id}"
  user_pool_id = aws_cognito_user_pool.app.id
}

resource "aws_iam_role" "ec2_role" {
  name = "ec2-ssm-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy" "ec2_read_db_secret" {
  name = "AllowEc2ReadDbSecret"
  role = aws_iam_role.ec2_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "secretsmanager:GetSecretValue"
      ]
      Resource = aws_secretsmanager_secret.db.arn
    }]
  })
}

resource "aws_iam_instance_profile" "ec2_profile" {
  name = "ec2-ssm-profile"
  role = aws_iam_role.ec2_role.name
}

output "vpc_id" {
  value = aws_vpc.main.id
}

output "alb_dns_name" {
  value = aws_lb.main.dns_name
}

output "cloudfront_domain_name" {
  value = aws_cloudfront_distribution.app.domain_name
}

output "cloudfront_url" {
  value = "https://${aws_cloudfront_distribution.app.domain_name}"
}

output "cognito_user_pool_id" {
  value = aws_cognito_user_pool.app.id
}

output "cognito_user_pool_client_id" {
  value = aws_cognito_user_pool_client.web.id
}

output "cognito_domain" {
  value = "https://${aws_cognito_user_pool_domain.main.domain}.auth.${data.aws_region.current.name}.amazoncognito.com"
}

output "cognito_login_url" {
  value = "https://${aws_cognito_user_pool_domain.main.domain}.auth.${data.aws_region.current.name}.amazoncognito.com/login?client_id=${aws_cognito_user_pool_client.web.id}&response_type=code&scope=email+openid+profile&redirect_uri=${urlencode(local.cognito_callback_url)}"
}

output "cognito_callback_url" {
  value = local.cognito_callback_url
}

output "cognito_logout_url" {
  value = local.cognito_logout_url
}

output "ecr_repository_url" {
  value = aws_ecr_repository.app.repository_url
}

output "rds_endpoint" {
  value = aws_db_instance.health.address
}

output "rds_port" {
  value = aws_db_instance.health.port
}

output "db_secret_arn" {
  value = aws_secretsmanager_secret.db.arn
}

output "db_name" {
  value = local.db_name
}

output "db_username" {
  value = local.db_username
}

output "aws_region" {
  value = data.aws_region.current.name
}

output "temporary_ec2_subnet_id" {
  value = aws_subnet.public_a.id
}

output "temporary_ec2_security_group_id" {
  value = aws_security_group.ec2.id
}

output "temporary_ec2_instance_profile_name" {
  value = aws_iam_instance_profile.ec2_profile.name
}

output "temporary_ec2_ami_id" {
  value = nonsensitive(data.aws_ssm_parameter.al2023_ami.value)
}
