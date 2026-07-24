# ─────────────────────────────────────────────────────────────
# Prod Environment
# Same modules as dev, but with production-grade sizing
# NOTE: This is meant to `terraform plan` cleanly, not necessarily `apply`
# ─────────────────────────────────────────────────────────────

terraform {
  required_version = ">= 1.7.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }

  backend "s3" {
    bucket         = "trading-platform-tf-state-424999960857"
    key            = "prod/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "trading-platform-tf-lock"
    encrypt        = true
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "trading-platform"
      Environment = "prod"
      ManagedBy   = "terraform"
    }
  }
}

# ─────────────────────────────────────────────────────────────
# Variables
# ─────────────────────────────────────────────────────────────

variable "aws_region" {
  default = "us-east-1"
}

variable "certificate_arn" {
  description = "ACM certificate ARN for HTTPS"
  type        = string
}

variable "api_image" {
  description = "ECR image URI for the API"
  type        = string
}

variable "worker_image" {
  description = "ECR image URI for the Worker"
  type        = string
}

variable "alarm_email" {
  description = "Email for alarm notifications"
  type        = string
  default     = ""
}

# ─────────────────────────────────────────────────────────────
# VPC
# ─────────────────────────────────────────────────────────────

module "vpc" {
  source = "../../modules/vpc"

  environment        = "prod"
  vpc_cidr           = "10.1.0.0/16" # Different CIDR from dev
  availability_zones = ["us-east-1a", "us-east-1b"]
  single_nat_gateway = false # One NAT per AZ for resilience
}

# ─────────────────────────────────────────────────────────────
# RDS (Postgres)
# ─────────────────────────────────────────────────────────────

module "rds" {
  source = "../../modules/rds"

  environment                = "prod"
  vpc_id                     = module.vpc.vpc_id
  private_subnet_ids         = module.vpc.private_subnet_ids
  instance_class             = "db.t3.small" # More power
  allocated_storage          = 50
  multi_az                   = true  # High availability
  deletion_protection        = true  # Prevent accidental deletion
  backup_retention_period    = 7
  allowed_security_group_ids = [module.ecs.ecs_tasks_security_group_id]
}

# ─────────────────────────────────────────────────────────────
# ALB
# ─────────────────────────────────────────────────────────────

module "alb" {
  source = "../../modules/alb"

  environment       = "prod"
  vpc_id            = module.vpc.vpc_id
  public_subnet_ids = module.vpc.public_subnet_ids
  certificate_arn   = var.certificate_arn
}

# ─────────────────────────────────────────────────────────────
# ECS (API + Worker + NATS)
# ─────────────────────────────────────────────────────────────

module "ecs" {
  source = "../../modules/ecs"

  environment    = "prod"
  vpc_id         = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids
  aws_region     = var.aws_region

  api_image    = var.api_image
  worker_image = var.worker_image

  # Prod sizing — more resources, more replicas
  api_cpu           = 512
  api_memory        = 1024
  worker_cpu        = 512
  worker_memory     = 1024
  nats_cpu          = 256
  nats_memory       = 512
  api_desired_count    = 2  # Multiple replicas for HA
  worker_desired_count = 2

  # Database connection
  database_host          = module.rds.address
  database_name          = module.rds.db_name
  database_username      = module.rds.username
  db_password_secret_arn = module.rds.password_secret_arn
  database_url_arn       = module.rds.password_secret_arn

  # ALB target group
  target_group_arn = module.alb.target_group_arn
}

# ─────────────────────────────────────────────────────────────
# Observability
# ─────────────────────────────────────────────────────────────

module "observability" {
  source = "../../modules/observability"

  environment                = "prod"
  alb_arn_suffix             = aws_lb_data.arn_suffix
  api_target_group_arn_suffix = aws_tg_data.arn_suffix
  ecs_cluster_name           = module.ecs.cluster_name
  api_service_name           = module.ecs.api_service_name
  worker_service_name        = module.ecs.worker_service_name
  rds_instance_id            = "prod-trading-db"
  alarm_email                = var.alarm_email
}

# ─────────────────────────────────────────────────────────────
# Outputs
# ─────────────────────────────────────────────────────────────

output "alb_dns_name" {
  value = module.alb.alb_dns_name
}

output "rds_endpoint" {
  value = module.rds.endpoint
}
