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

variable "image_uri" {
  type        = string
  description = "Full Docker image URI pushed by GitHub Actions, for example: ??????.dkr.ecr.us-east-1.amazonaws.com/customermanagementapp:github-sha"
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

  container_port   = 3000
  health_check_path = "/"
  cpu              = 256
  memory           = 512

  db_engine   = "mysql"
  db_name     = "healthcaredb"
  db_username = "admin"
  db_port     = 3306

  common_tags = {
    Environment = local.environment
  }
}

data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_ssm_parameter" "al2023_ami" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
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
    description = "HTTP from internet"
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

resource "aws_security_group" "fargate" {
  name        = "healthcare-fargate-sg"
  description = "Allow ALB to Fargate tasks"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "App traffic from ALB"
    protocol        = "tcp"
    from_port       = local.container_port
    to_port         = local.container_port
    security_groups = [aws_security_group.alb.id]
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
  description = "Allow MySQL access from Fargate and EC2"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "MySQL from Fargate tasks"
    protocol        = "tcp"
    from_port       = local.db_port
    to_port         = local.db_port
    security_groups = [aws_security_group.fargate.id]
  }

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
  identifier             = "db-health"
  instance_class         = "db.t3.micro"
  allocated_storage      = 20
  storage_type           = "gp2"
  engine                 = local.db_engine
  db_name                = local.db_name
  username               = local.db_username
  password               = var.db_password
  port                   = local.db_port
  availability_zone      = data.aws_availability_zones.available.names[0]
  multi_az               = false
  publicly_accessible    = false
  backup_retention_period = 0
  deletion_protection    = false
  skip_final_snapshot    = true
  vpc_security_group_ids = [aws_security_group.rds.id]
  db_subnet_group_name   = aws_db_subnet_group.main.name

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
      Resource = aws_secretsmanager_secret.db.arn
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
      image     = var.image_uri
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
          valueFrom = "${aws_secretsmanager_secret.db.arn}:engine::"
        },
        {
          name      = "DB_HOST"
          valueFrom = "${aws_secretsmanager_secret.db.arn}:host::"
        },
        {
          name      = "DB_PORT"
          valueFrom = "${aws_secretsmanager_secret.db.arn}:port::"
        },
        {
          name      = "DB_NAME"
          valueFrom = "${aws_secretsmanager_secret.db.arn}:dbname::"
        },
        {
          name      = "DB_USER"
          valueFrom = "${aws_secretsmanager_secret.db.arn}:username::"
        },
        {
          name      = "DB_PASS"
          valueFrom = "${aws_secretsmanager_secret.db.arn}:password::"
        }
      ]
    }
  ])

  depends_on = [
    aws_iam_role_policy_attachment.ecs_task_execution_policy,
    aws_iam_role_policy.ecs_read_db_secret,
    aws_secretsmanager_secret_version.db
  ]

  tags = local.common_tags
}

resource "aws_ecs_service" "app" {
  name            = "healthcare-fargate-service"
  cluster         = aws_ecs_cluster.main.id
  launch_type     = "FARGATE"
  desired_count   = 1
  task_definition = aws_ecs_task_definition.app.arn

  network_configuration {
    assign_public_ip = true
    subnets          = [aws_subnet.public_a.id, aws_subnet.public_b.id]
    security_groups  = [aws_security_group.fargate.id]
  }

  load_balancer {
    container_name   = "app"
    container_port   = local.container_port
    target_group_arn = aws_lb_target_group.app.arn
  }

  depends_on = [aws_lb_listener.http]

  tags = local.common_tags
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

output "rds_endpoint" {
  value = aws_db_instance.health.address
}

output "rds_port" {
  value = aws_db_instance.health.port
}

output "db_secret_arn" {
  value = aws_secretsmanager_secret.db.arn
}


output "image_uri_used_by_ecs" {
  value = var.image_uri
}

output "db_name" {
  value = local.db_name
}

output "db_username" {
  value = local.db_username
}

output "aws_region" {
  value = "us-east-1"
}
