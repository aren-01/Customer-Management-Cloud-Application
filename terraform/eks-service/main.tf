terraform {
  required_version = ">= 1.10.0"

  backend "s3" {}

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.82.0, < 7.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

locals {
  environment           = "sandbox"
  app_name              = "healthcare"
  vpc_cidr              = "10.20.0.0/16"
  public_subnet_a_cidr  = "10.20.101.0/24"
  public_subnet_b_cidr  = "10.20.102.0/24"
  private_subnet_a_cidr = "10.20.201.0/24"
  private_subnet_b_cidr = "10.20.202.0/24"

  ecr_repository_name = "customermanagementapp"

  # Placeholders since CloudFront is removed
  cognito_callback_url = "https://example.com/auth/callback"
  cognito_logout_url   = "https://example.com/"

  interface_vpc_endpoint_services = toset([
    "ecr.api",
    "ecr.dkr",
    "logs",
    "ssm",
    "ssmmessages",
    "ec2messages"
  ])

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

resource "aws_ecr_repository" "app" {
  name                 = local.ecr_repository_name
  image_tag_mutability = "MUTABLE"
  force_delete         = true

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
    Name = "MainIGW"
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

# Dedicated private subnets for private management resources.
# These subnets do not receive public IPs and do not have a default route to the Internet Gateway.
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

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = merge(local.common_tags, {
    Name = "PublicRouteTable"
  })
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  tags = merge(local.common_tags, {
    Name = "PrivateRouteTable"
  })
}

resource "aws_route_table_association" "public_a" {
  subnet_id      = aws_subnet.public_a.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public_b" {
  subnet_id      = aws_subnet.public_b.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private_a" {
  subnet_id      = aws_subnet.private_a.id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "private_b" {
  subnet_id      = aws_subnet.private_b.id
  route_table_id = aws_route_table.private.id
}

resource "aws_security_group" "vpc_endpoints" {
  name        = "healthcare-vpc-endpoints-sg"
  description = "Allow VPC subnets to reach AWS service VPC endpoints"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "HTTPS from inside VPC"
    protocol    = "tcp"
    from_port   = 443
    to_port     = 443
    cidr_blocks = [local.vpc_cidr]
  }

  egress {
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name = "VpcEndpointsSG"
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

resource "aws_vpc_endpoint" "interface" {
  for_each = local.interface_vpc_endpoint_services

  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${data.aws_region.current.name}.${each.value}"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [aws_subnet.private_a.id, aws_subnet.private_b.id]
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
  private_dns_enabled = true

  tags = merge(local.common_tags, {
    Name = "${each.value}-endpoint"
  })
}

resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.${data.aws_region.current.name}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [aws_route_table.private.id]

  tags = merge(local.common_tags, {
    Name = "s3-gateway-endpoint"
  })
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

  generate_secret                      = true
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

resource "aws_iam_instance_profile" "ec2_profile" {
  name = "ec2-ssm-profile"
  role = aws_iam_role.ec2_role.name
}

output "vpc_id" {
  value = aws_vpc.main.id
}

output "public_subnet_ids" {
  description = "Public subnet IDs"
  value       = [aws_subnet.public_a.id, aws_subnet.public_b.id]
}

output "private_subnet_ids" {
  description = "Private subnet IDs"
  value       = [aws_subnet.private_a.id, aws_subnet.private_b.id]
}

output "cognito_user_pool_id" {
  value = aws_cognito_user_pool.app.id
}

output "cognito_user_pool_client_id" {
  value = aws_cognito_user_pool_client.web.id
}

output "cognito_user_pool_client_secret" {
  value     = aws_cognito_user_pool_client.web.client_secret
  sensitive = true
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

output "vpc_interface_endpoint_ids" {
  value = { for service, endpoint in aws_vpc_endpoint.interface : service => endpoint.id }
}

output "s3_gateway_endpoint_id" {
  value = aws_vpc_endpoint.s3.id
}

output "aws_region" {
  value = data.aws_region.current.name
}

output "temporary_ec2_subnet_id" {
  value = aws_subnet.private_a.id
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

output "internet_gateway_id" {
  value = aws_internet_gateway.main.id
}
