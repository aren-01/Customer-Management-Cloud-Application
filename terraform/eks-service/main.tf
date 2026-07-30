terraform {
  required_version = ">= 1.10.0"

  backend "s3" {}

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.82.0, < 7.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

variable "cloudfront_secret" {
  type        = string
  description = "Custom secret header value supplied by GitHub Actions"
  sensitive   = true
}

variable "db_user" {
  type        = string
  description = "Database user supplied by GitHub Actions"
  sensitive   = true
}

variable "db_pass" {
  type        = string
  description = "Database password supplied by GitHub Actions"
  sensitive   = true
}

variable "session_secret" {
  type        = string
  description = "App session secret supplied by GitHub Actions"
  sensitive   = true
}

locals {
  environment           = "sandbox"
  app_name              = "healthcare"
  cluster_name          = "customer-management-app"
  vpc_cidr              = "10.20.0.0/16"
  public_subnet_a_cidr  = "10.20.101.0/24"
  public_subnet_b_cidr  = "10.20.102.0/24"
  private_subnet_a_cidr = "10.20.201.0/24"
  private_subnet_b_cidr = "10.20.202.0/24"

  ecr_repository_name = "customermanagementapp"

  custom_origin_domain = "example.com"
  cloudfront_origin_id = "custom-http-origin"

  eks_cluster_policies = [
    "arn:aws:iam::aws:policy/AmazonEKSBlockStoragePolicyV2",
    "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy",
    "arn:aws:iam::aws:policy/AmazonEKSComputePolicy",
    "arn:aws:iam::aws:policy/AmazonEKSLoadBalancingPolicy",
    "arn:aws:iam::aws:policy/AmazonEKSNetworkingPolicy"
  ]

  eks_node_policies = [
    "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPullOnly",
    "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly",
    "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy",
    "arn:aws:iam::aws:policy/AmazonEKSWorkerNodeMinimalPolicy",
    "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy",
    "arn:aws:iam::aws:policy/AmazonElasticContainerRegistryPublicReadOnly"
  ]

  common_tags = {
    Environment = local.environment
  }
}

data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

data "aws_cloudfront_cache_policy" "caching_disabled" {
  name = "Managed-CachingDisabled"
}

data "aws_cloudfront_origin_request_policy" "all_viewer" {
  name = "Managed-AllViewer"
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
    Name                                           = "PublicSubnet-${data.aws_availability_zones.available.names[0]}"
    "kubernetes.io/cluster/${local.cluster_name}" = "shared"
    "kubernetes.io/role/elb"                       = "1"
  })
}

resource "aws_subnet" "public_b" {
  vpc_id                  = aws_vpc.main.id
  availability_zone       = data.aws_availability_zones.available.names[1]
  cidr_block              = local.public_subnet_b_cidr
  map_public_ip_on_launch = true

  tags = merge(local.common_tags, {
    Name                                           = "PublicSubnet-${data.aws_availability_zones.available.names[1]}"
    "kubernetes.io/cluster/${local.cluster_name}" = "shared"
    "kubernetes.io/role/elb"                       = "1"
  })
}

resource "aws_subnet" "private_a" {
  vpc_id                  = aws_vpc.main.id
  availability_zone       = data.aws_availability_zones.available.names[0]
  cidr_block              = local.private_subnet_a_cidr
  map_public_ip_on_launch = false

  tags = merge(local.common_tags, {
    Name                                           = "PrivateSubnet-${data.aws_availability_zones.available.names[0]}"
    "kubernetes.io/cluster/${local.cluster_name}" = "shared"
    "kubernetes.io/role/internal-elb"              = "1"
  })
}

resource "aws_subnet" "private_b" {
  vpc_id                  = aws_vpc.main.id
  availability_zone       = data.aws_availability_zones.available.names[1]
  cidr_block              = local.private_subnet_b_cidr
  map_public_ip_on_launch = false

  tags = merge(local.common_tags, {
    Name                                           = "PrivateSubnet-${data.aws_availability_zones.available.names[1]}"
    "kubernetes.io/cluster/${local.cluster_name}" = "shared"
    "kubernetes.io/role/internal-elb"              = "1"
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
    require_lowercase                 = true
    require_numbers                   = true
    require_symbols                   = false
    require_uppercase                 = true
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
  callback_urls                        = ["https://${aws_cloudfront_distribution.app.domain_name}/auth/callback"]
  logout_urls                          = ["https://${aws_cloudfront_distribution.app.domain_name}/"]

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

resource "aws_cloudfront_distribution" "app" {
  enabled         = true
  is_ipv6_enabled = true
  comment         = "CloudFront distribution with custom HTTP origin for ${local.app_name} ${local.environment}"
  price_class     = "PriceClass_100"

  origin {
    domain_name = local.custom_origin_domain
    origin_id   = local.cloudfront_origin_id

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "http-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }

    custom_header {
      name  = "X-CloudFront-Secret"
      value = var.cloudfront_secret
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

  tags = local.common_tags
}

resource "aws_iam_role" "eks_cluster_role" {
  name = "customer-app-eks-cluster-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "eks.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })

  tags = merge(local.common_tags, {
    Name = "customer-app-eks-cluster-role"
  })
}

resource "aws_iam_role_policy_attachment" "eks_cluster_role_policies" {
  for_each   = toset(local.eks_cluster_policies)
  role       = aws_iam_role.eks_cluster_role.name
  policy_arn = each.value
}

resource "aws_iam_role" "eks_node_role" {
  name = "customer-app-eks-node-role"

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

  tags = merge(local.common_tags, {
    Name = "customer-app-eks-node-role"
  })
}

resource "aws_iam_role_policy_attachment" "eks_node_role_policies" {
  for_each   = toset(local.eks_node_policies)
  role       = aws_iam_role.eks_node_role.name
  policy_arn = each.value
}

resource "aws_eks_cluster" "app" {
  name     = local.cluster_name
  role_arn = aws_iam_role.eks_cluster_role.arn

  vpc_config {
    subnet_ids = [
      aws_subnet.private_a.id,
      aws_subnet.private_b.id,
      aws_subnet.public_a.id,
      aws_subnet.public_b.id
    ]
  }

  access_config {
    authentication_mode                         = "API_AND_CONFIG_MAP"
    bootstrap_cluster_creator_admin_permissions = true
  }

  depends_on = [
    aws_iam_role_policy_attachment.eks_cluster_role_policies
  ]

  tags = local.common_tags
}

resource "aws_eks_access_entry" "node_linux" {
  cluster_name  = aws_eks_cluster.app.name
  principal_arn = aws_iam_role.eks_node_role.arn
  type          = "EC2_LINUX"
}

data "tls_certificate" "eks" {
  url = aws_eks_cluster.app.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "eks" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.eks.certificates[0].sha1_fingerprint]
  url             = aws_eks_cluster.app.identity[0].oidc[0].issuer
}

resource "aws_iam_role" "ebs_csi_driver" {
  name = "${local.cluster_name}-ebs-csi-driver-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.eks.arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "${replace(aws_iam_openid_connect_provider.eks.url, "https://", "")}:sub" = "system:serviceaccount:kube-system:ebs-csi-controller-sa",
            "${replace(aws_iam_openid_connect_provider.eks.url, "https://", "")}:aud" = "sts.amazonaws.com"
          }
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ebs_csi_driver" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
  role       = aws_iam_role.ebs_csi_driver.name
}

resource "aws_eks_addon" "vpc_cni" {
  cluster_name = aws_eks_cluster.app.name
  addon_name   = "vpc-cni"
}

resource "aws_eks_addon" "kube_proxy" {
  cluster_name = aws_eks_cluster.app.name
  addon_name   = "kube-proxy"
}

# --- LAUNCH TEMPLATE FOR CUSTOM EBS NODE DISK SIZE ---
resource "aws_launch_template" "app_nodes" {
  name_prefix = "db-and-app-nodes-"

  block_device_mappings {
    device_name = "/dev/xvda"

    ebs {
      volume_size           = 20 # Minimum valid AWS EKS root volume size in GiB
      volume_type           = "gp3"
      delete_on_termination = true
    }
  }

  tags = local.common_tags
}

resource "aws_eks_node_group" "app" {
  cluster_name    = aws_eks_cluster.app.name
  node_group_name = "db-and-app"
  node_role_arn   = aws_iam_role.eks_node_role.arn
  subnet_ids      = [aws_subnet.public_a.id, aws_subnet.public_b.id]
  instance_types  = ["t3.small"]

  launch_template {
    id      = aws_launch_template.app_nodes.id
    version = aws_launch_template.app_nodes.latest_version
  }

  scaling_config {
    desired_size = 4
    max_size     = 6
    min_size     = 2
  }

  depends_on = [
    aws_iam_role_policy_attachment.eks_node_role_policies,
    aws_eks_access_entry.node_linux
  ]

  tags = local.common_tags
}

resource "aws_eks_addon" "ebs_csi" {
  cluster_name             = aws_eks_cluster.app.name
  addon_name               = "aws-ebs-csi-driver"
  service_account_role_arn = aws_iam_role.ebs_csi_driver.arn

  depends_on = [
    aws_eks_node_group.app,
    aws_iam_role_policy_attachment.ebs_csi_driver
  ]
}

resource "random_password" "db_root_password" {
  length  = 16
  special = false
}

resource "aws_secretsmanager_secret" "app_secrets" {
  name                    = "my-app/production-secrets"
  description             = "App and Database secrets provisioned by Terraform"
  recovery_window_in_days = 0 
  
  tags = local.common_tags
}

resource "aws_secretsmanager_secret_version" "app_secrets_val" {
  secret_id = aws_secretsmanager_secret.app_secrets.id
  secret_string = jsonencode({
    DB_USER           = var.db_user
    DB_PASSWORD       = var.db_pass
    SESSION_SECRET    = var.session_secret
    CLOUDFRONT_SECRET = var.cloudfront_secret

    DB_NAME           = "db_health"
    DB_ROOT_PASSWORD  = random_password.db_root_password.result
    APP_BASE_URL      = "https://${aws_cloudfront_distribution.app.domain_name}"
    
    COGNITO_DOMAIN        = "https://${aws_cognito_user_pool_domain.main.domain}.auth.${data.aws_region.current.region}.amazoncognito.com"
    COGNITO_USER_POOL_ID  = aws_cognito_user_pool.app.id
    COGNITO_CLIENT_ID     = aws_cognito_user_pool_client.web.id
    COGNITO_CLIENT_SECRET = aws_cognito_user_pool_client.web.client_secret
  })
}

# --- EXTERNAL SECRETS OPERATOR IRSA ROLE & POLICY ---

resource "aws_iam_role" "external_secrets" {
  name = "${local.cluster_name}-external-secrets-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.eks.arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "${replace(aws_iam_openid_connect_provider.eks.url, "https://", "")}:sub" = "system:serviceaccount:default:aws-secrets-sa",
            "${replace(aws_iam_openid_connect_provider.eks.url, "https://", "")}:aud" = "sts.amazonaws.com"
          }
        }
      }
    ]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy" "external_secrets_policy" {
  name = "SecretsManagerReadPolicy"
  role = aws_iam_role.external_secrets.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = aws_secretsmanager_secret.app_secrets.arn
      }
    ]
  })
}

# --- OUTPUTS ---

output "vpc_id" {
  value = aws_vpc.main.id
}

output "public_subnet_ids" {
  value = [aws_subnet.public_a.id, aws_subnet.public_b.id]
}

output "private_subnet_ids" {
  value = [aws_subnet.private_a.id, aws_subnet.private_b.id]
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

output "cognito_user_pool_client_secret" {
  value     = aws_cognito_user_pool_client.web.client_secret
  sensitive = true
}

output "cognito_domain" {
  value = "https://${aws_cognito_user_pool_domain.main.domain}.auth.${data.aws_region.current.region}.amazoncognito.com"
}

output "cognito_login_url" {
  value = "https://${aws_cognito_user_pool_domain.main.domain}.auth.${data.aws_region.current.region}.amazoncognito.com/login?client_id=${aws_cognito_user_pool_client.web.id}&response_type=code&scope=email+openid+profile&redirect_uri=${urlencode("https://${aws_cloudfront_distribution.app.domain_name}/auth/callback")}"
}

output "cognito_callback_url" {
  value = "https://${aws_cloudfront_distribution.app.domain_name}/auth/callback"
}

output "cognito_logout_url" {
  value = "https://${aws_cloudfront_distribution.app.domain_name}/"
}

output "ecr_repository_url" {
  value = aws_ecr_repository.app.repository_url
}

output "aws_region" {
  value = data.aws_region.current.region
}

output "eks_subnet" {
  value = aws_subnet.private_a.id
}

output "internet_gateway_id" {
  value = aws_internet_gateway.main.id
}

output "eks_cluster_name" {
  value = aws_eks_cluster.app.name
}

output "eks_cluster_endpoint" {
  value = aws_eks_cluster.app.endpoint
}

output "cloudfront_distribution_id" {
  description = "The ID of the CloudFront distribution"
  value       = aws_cloudfront_distribution.app.id 
}

output "eks_cluster_role_arn" {
  value = aws_iam_role.eks_cluster_role.arn
}

output "eks_node_role_arn" {
  value = aws_iam_role.eks_node_role.arn
}

output "external_secrets_role_arn" {
  value = aws_iam_role.external_secrets.arn
}
