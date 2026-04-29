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

  container_port = 3000
  cpu            = 256
  memory         = 512
  db_port        = 3306

  common_tags = {
    Environment = local.environment
  }
}

provider "aws" {
  region = local.aws_region
}

variable "ecr_repository_url" {
  type        = string
  description = "ECR repository URL from the infrastructure stack, for example 123456789012.dkr.ecr.us-east-1.amazonaws.com/customermanagementapp."
}

variable "image_tag" {
  type        = string
  description = "Image tag to deploy from the ECR repository. GitHub Actions can pass the commit SHA here."
  default     = "latest"
}

variable "vpc_id" {
  type        = string
  description = "VPC ID created by the infrastructure stack."
}

variable "public_subnet_ids" {
  type        = list(string)
  description = "Public subnet IDs created by the infrastructure stack for the ECS service ENIs."
}

variable "alb_security_group_id" {
  type        = string
  description = "ALB security group ID created by the infrastructure stack."
}

variable "rds_security_group_id" {
  type        = string
  description = "RDS security group ID created by the infrastructure stack. This stack adds an ingress rule from ECS tasks."
}

variable "target_group_arn" {
  type        = string
  description = "ALB target group ARN created by the infrastructure stack."
}

variable "alb_listener_arn" {
  type        = string
  description = "ALB listener ARN created by the infrastructure stack. Used to ensure the listener exists before the ECS service is created."
}

variable "db_secret_arn" {
  type        = string
  description = "Secrets Manager secret ARN created by the infrastructure stack. Must contain engine, host, port, dbname, username, and password JSON keys."
}

variable "desired_count" {
  type        = number
  description = "Number of ECS tasks to run."
  default     = 1
}

resource "aws_security_group" "fargate" {
  name        = "healthcare-fargate-sg"
  description = "Allow ALB to Fargate tasks"
  vpc_id      = var.vpc_id

  ingress {
    description     = "App traffic from ALB"
    protocol        = "tcp"
    from_port       = local.container_port
    to_port         = local.container_port
    security_groups = [var.alb_security_group_id]
  }

  egress {
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name = "FargateSG"
  })
}

resource "aws_security_group_rule" "rds_from_fargate" {
  type                     = "ingress"
  description              = "MySQL from Fargate tasks"
  from_port                = local.db_port
  to_port                  = local.db_port
  protocol                 = "tcp"
  security_group_id        = var.rds_security_group_id
  source_security_group_id = aws_security_group.fargate.id
}

resource "aws_ecs_cluster" "main" {
  name = "healthcare-ecs-cluster"

  tags = local.common_tags
}

resource "aws_iam_role" "ecs_task_execution_role" {
  name = "healthcare-ecs-exec-sandbox"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "ecs-tasks.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_policy" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role_policy" "ecs_read_db_secret" {
  name = "AllowReadDbSecret"
  role = aws_iam_role.ecs_task_execution_role.id

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

resource "aws_ecs_task_definition" "app" {
  family                   = "healthcare-app-sandbox"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = tostring(local.cpu)
  memory                   = tostring(local.memory)
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn

  container_definitions = jsonencode([
    {
      name      = "app"
      image     = "${var.ecr_repository_url}:${var.image_tag}"
      essential = true

      portMappings = [
        {
          containerPort = local.container_port
          protocol      = "tcp"
        }
      ]

      secrets = [
        {
          name      = "DB_ENGINE"
          valueFrom = "${var.db_secret_arn}:engine::"
        },
        {
          name      = "DB_HOST"
          valueFrom = "${var.db_secret_arn}:host::"
        },
        {
          name      = "DB_PORT"
          valueFrom = "${var.db_secret_arn}:port::"
        },
        {
          name      = "DB_NAME"
          valueFrom = "${var.db_secret_arn}:dbname::"
        },
        {
          name      = "DB_USER"
          valueFrom = "${var.db_secret_arn}:username::"
        },
        {
          name      = "DB_PASS"
          valueFrom = "${var.db_secret_arn}:password::"
        }
      ]
    }
  ])

  depends_on = [
    aws_iam_role_policy_attachment.ecs_task_execution_policy,
    aws_iam_role_policy.ecs_read_db_secret
  ]

  tags = local.common_tags
}

resource "aws_ecs_service" "app" {
  name            = "healthcare-fargate-service"
  cluster         = aws_ecs_cluster.main.id
  launch_type     = "FARGATE"
  desired_count   = var.desired_count
  task_definition = aws_ecs_task_definition.app.arn

  network_configuration {
    assign_public_ip = true
    subnets          = var.public_subnet_ids
    security_groups  = [aws_security_group.fargate.id]
  }

  load_balancer {
    container_name   = "app"
    container_port   = local.container_port
    target_group_arn = var.target_group_arn
  }

  depends_on = [
    aws_security_group_rule.rds_from_fargate,
    aws_iam_role_policy_attachment.ecs_task_execution_policy,
    aws_iam_role_policy.ecs_read_db_secret
  ]

  tags = local.common_tags
}

output "ecs_cluster_name" {
  value = aws_ecs_cluster.main.name
}

output "ecs_cluster_arn" {
  value = aws_ecs_cluster.main.arn
}

output "ecs_service_name" {
  value = aws_ecs_service.app.name
}

output "ecs_service_id" {
  value = aws_ecs_service.app.id
}

output "ecs_task_definition_arn" {
  value = aws_ecs_task_definition.app.arn
}

output "ecs_task_image" {
  value = "${var.ecr_repository_url}:${var.image_tag}"
}

output "fargate_security_group_id" {
  value = aws_security_group.fargate.id
}

output "aws_region" {
  value = local.aws_region
}
