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
  aws_region = "us-east-1"
}

provider "aws" {
  region = local.aws_region
}

resource "aws_ecr_repository" "customermanagementapp" {
  name         = "customermanagementapp"
  force_delete = true

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name        = "customermanagementapp"
    Environment = "sandbox"
  }
}

output "repository_url" {
  description = "Full ECR repository URL used for docker build/push."
  value       = aws_ecr_repository.customermanagementapp.repository_url
}

output "registry_url" {
  description = "Base ECR registry URL used for docker login."
  value       = split("/", aws_ecr_repository.customermanagementapp.repository_url)[0]
}

output "repository_name" {
  value = aws_ecr_repository.customermanagementapp.name
}

output "aws_region" {
  description = "AWS region used by the ECR repository and GitHub Actions ECR login."
  value       = local.aws_region
}
