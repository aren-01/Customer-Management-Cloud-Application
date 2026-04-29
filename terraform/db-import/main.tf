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

locals {
  aws_region  = "us-east-1"
  environment = "sandbox"
  app_name    = "healthcare"
  db_port     = 3306

  common_tags = {
    Environment = local.environment
    ManagedBy   = "terraform"
    Purpose     = "temporary-db-import"
  }
}

provider "aws" {
  region = local.aws_region
}

variable "vpc_id" {
  type        = string
  description = "VPC ID from the infrastructure stack."
}

variable "internet_gateway_id" {
  type        = string
  description = "Internet Gateway ID from the infrastructure stack. CloudFront VPC Origin still needs the IGW to remain in the main infrastructure stack."
}

variable "rds_security_group_id" {
  type        = string
  description = "RDS security group ID from the infrastructure stack. This temporary stack adds and later removes MySQL access from the DB import EC2 security group."
}

variable "db_secret_arn" {
  type        = string
  description = "Secrets Manager DB secret ARN from the infrastructure stack. The temporary EC2 instance can read this secret during import."
}

variable "db_import_ami_id" {
  type        = string
  description = "AMI ID for the temporary DB import EC2 instance. Amazon Linux 2023 works if this stack launches it in a public subnet and installs mariadb105 during the workflow."
}

variable "public_subnet_cidr" {
  type        = string
  description = "Temporary public subnet CIDR used only for DB import EC2. Must not overlap existing VPC subnets."
  default     = "10.20.1.0/24"
}

variable "instance_type" {
  type        = string
  description = "Temporary DB import EC2 instance type."
  default     = "t3.micro"
}

data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_subnet" "db_import_public" {
  vpc_id                  = var.vpc_id
  availability_zone       = data.aws_availability_zones.available.names[0]
  cidr_block              = var.public_subnet_cidr
  map_public_ip_on_launch = true

  tags = merge(local.common_tags, {
    Name = "${local.app_name}-${local.environment}-db-import-public-subnet"
  })
}

resource "aws_route_table" "db_import_public" {
  vpc_id = var.vpc_id

  tags = merge(local.common_tags, {
    Name = "${local.app_name}-${local.environment}-db-import-public-rt"
  })
}

resource "aws_route" "public_internet" {
  route_table_id         = aws_route_table.db_import_public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = var.internet_gateway_id
}

resource "aws_route_table_association" "db_import_public" {
  subnet_id      = aws_subnet.db_import_public.id
  route_table_id = aws_route_table.db_import_public.id
}

resource "aws_security_group" "db_import_ec2" {
  name        = "${local.app_name}-${local.environment}-db-import-ec2-sg"
  description = "Temporary EC2 SG for DB import; no inbound access required"
  vpc_id      = var.vpc_id

  egress {
    description = "Allow outbound traffic for SSM, package install, Secrets Manager, and RDS"
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name = "${local.app_name}-${local.environment}-db-import-ec2-sg"
  })
}

resource "aws_security_group_rule" "rds_from_db_import_ec2" {
  type                     = "ingress"
  description              = "Temporary MySQL access from DB import EC2"
  from_port                = local.db_port
  to_port                  = local.db_port
  protocol                 = "tcp"
  security_group_id        = var.rds_security_group_id
  source_security_group_id = aws_security_group.db_import_ec2.id
}

resource "aws_iam_role" "db_import_ec2" {
  name = "${local.app_name}-${local.environment}-db-import-ec2-role"

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
  role       = aws_iam_role.db_import_ec2.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy" "read_db_secret" {
  name = "AllowReadDbSecret"
  role = aws_iam_role.db_import_ec2.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "secretsmanager:GetSecretValue"
      ]
      Resource = var.db_secret_arn
    }]
  })
}

resource "aws_iam_instance_profile" "db_import_ec2" {
  name = "${local.app_name}-${local.environment}-db-import-ec2-profile"
  role = aws_iam_role.db_import_ec2.name
}

resource "aws_instance" "db_import" {
  ami                         = var.db_import_ami_id
  instance_type               = var.instance_type
  subnet_id                   = aws_subnet.db_import_public.id
  vpc_security_group_ids      = [aws_security_group.db_import_ec2.id]
  iam_instance_profile        = aws_iam_instance_profile.db_import_ec2.name
  associate_public_ip_address = true

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  depends_on = [
    aws_route.public_internet,
    aws_route_table_association.db_import_public,
    aws_iam_role_policy_attachment.ssm,
    aws_iam_role_policy.read_db_secret,
    aws_security_group_rule.rds_from_db_import_ec2
  ]

  tags = merge(local.common_tags, {
    Name = "${local.app_name}-${local.environment}-temporary-db-import-ec2"
  })
}

output "aws_region" {
  value = local.aws_region
}

output "db_import_instance_id" {
  value = aws_instance.db_import.id
}

output "db_import_public_subnet_id" {
  value = aws_subnet.db_import_public.id
}

output "db_import_security_group_id" {
  value = aws_security_group.db_import_ec2.id
}

output "db_import_instance_profile_name" {
  value = aws_iam_instance_profile.db_import_ec2.name
}

output "db_import_ami_id" {
  value = var.db_import_ami_id
}

output "db_import_public_ip" {
  value = aws_instance.db_import.public_ip
}

output "rds_temporary_ingress_rule_id" {
  value = aws_security_group_rule.rds_from_db_import_ec2.id
}
