# ─────────────────────────────────────────────────────────────
# Dev Environment
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
    key            = "dev/terraform.tfstate"
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
      Environment = "dev"
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

variable "api_image" {
  description = "ECR image URI for the API"
  type        = string
  default     = "424999960857.dkr.ecr.us-east-1.amazonaws.com/trading-platform/api:latest"
}

variable "worker_image" {
  description = "ECR image URI for the Worker"
  type        = string
  default     = "424999960857.dkr.ecr.us-east-1.amazonaws.com/trading-platform/worker:latest"
}

variable "alarm_email" {
  description = "Email for alarm notifications"
  type        = string
  default     = ""
}

variable "domain_name" {
  description = "Root domain"
  type        = string
  default     = "platform-test.click"
}

# ─────────────────────────────────────────────────────────────
# DNS / TLS Certificate
# ─────────────────────────────────────────────────────────────

module "dns" {
  source = "../../modules/dns"

  environment = "dev"
  domain_name = var.domain_name
  subdomain   = "dev"
}

# ─────────────────────────────────────────────────────────────
# VPC
# ─────────────────────────────────────────────────────────────

module "vpc" {
  source = "../../modules/vpc"

  environment        = "dev"
  vpc_cidr           = "10.0.0.0/16"
  availability_zones = ["us-east-1a", "us-east-1b"]
  single_nat_gateway = true
}

# ─────────────────────────────────────────────────────────────
# RDS (Postgres) — uses VPC CIDR for access (no circular dep)
# ─────────────────────────────────────────────────────────────

module "rds" {
  source = "../../modules/rds"

  environment             = "dev"
  vpc_id                  = module.vpc.vpc_id
  private_subnet_ids      = module.vpc.private_subnet_ids
  vpc_cidr                = "10.0.0.0/16"
  instance_class          = "db.t3.micro"
  allocated_storage       = 20
  multi_az                = false
  deletion_protection     = false
  backup_retention_period = 1
}

# ─────────────────────────────────────────────────────────────
# ALB
# ─────────────────────────────────────────────────────────────

module "alb" {
  source = "../../modules/alb"

  environment       = "dev"
  vpc_id            = module.vpc.vpc_id
  public_subnet_ids = module.vpc.public_subnet_ids
  certificate_arn   = module.dns.certificate_arn
}

# ─────────────────────────────────────────────────────────────
# ECS (API + Worker + NATS)
# ─────────────────────────────────────────────────────────────

module "ecs" {
  source = "../../modules/ecs"

  environment        = "dev"
  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids
  aws_region         = var.aws_region

  api_image    = var.api_image
  worker_image = var.worker_image

  api_cpu              = 256
  api_memory           = 512
  worker_cpu           = 256
  worker_memory        = 512
  nats_cpu             = 256
  nats_memory          = 512
  api_desired_count    = 1
  worker_desired_count = 1

  database_host          = module.rds.address
  database_name          = module.rds.db_name
  database_username      = module.rds.username
  db_password_secret_arn = module.rds.password_secret_arn
  database_url_arn       = module.rds.password_secret_arn

  target_group_arn = module.alb.target_group_arn
}

# ─────────────────────────────────────────────────────────────
# Observability
# ─────────────────────────────────────────────────────────────

module "observability" {
  source = "../../modules/observability"

  environment                 = "dev"
  alb_arn_suffix              = module.alb.alb_arn_suffix
  api_target_group_arn_suffix = module.alb.target_group_arn_suffix
  ecs_cluster_name            = module.ecs.cluster_name
  api_service_name            = module.ecs.api_service_name
  worker_service_name         = module.ecs.worker_service_name
  rds_instance_id             = "dev-trading-db"
  alarm_email                 = var.alarm_email
}

# ─────────────────────────────────────────────────────────────
# Outputs
# ─────────────────────────────────────────────────────────────

output "alb_dns_name" {
  value = module.alb.alb_dns_name
}

output "app_url" {
  value = "https://dev.${var.domain_name}"
}

output "rds_endpoint" {
  value     = module.rds.endpoint
  sensitive = true
}

output "cert_validation_records" {
  description = "Add these CNAME records in your DNS to validate the certificate"
  value       = module.dns.domain_validation_options
}
