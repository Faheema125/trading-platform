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

variable "domain_name" {
  description = "Root domain"
  type        = string
  default     = "platform-test.click"
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
# DNS / TLS Certificate
# ─────────────────────────────────────────────────────────────

module "dns" {
  source = "../../modules/dns"

  environment = "prod"
  domain_name = var.domain_name
  subdomain   = "prod"
}

# ─────────────────────────────────────────────────────────────
# VPC
# ─────────────────────────────────────────────────────────────

module "vpc" {
  source = "../../modules/vpc"

  environment          = "prod"
  vpc_cidr             = "10.1.0.0/16"
  availability_zones   = ["us-east-1a", "us-east-1b"]
  public_subnet_cidrs  = ["10.1.1.0/24", "10.1.2.0/24"]
  private_subnet_cidrs = ["10.1.10.0/24", "10.1.11.0/24"]
  single_nat_gateway   = false
}

# ─────────────────────────────────────────────────────────────
# RDS (Postgres)
# ─────────────────────────────────────────────────────────────

module "rds" {
  source = "../../modules/rds"

  environment                = "prod"
  vpc_id                     = module.vpc.vpc_id
  private_subnet_ids         = module.vpc.private_subnet_ids
  vpc_cidr                   = "10.1.0.0/16"
  instance_class             = "db.t3.small"
  allocated_storage          = 50
  multi_az                   = true
  deletion_protection        = true
  backup_retention_period    = 7
}

# ─────────────────────────────────────────────────────────────
# ALB
# ─────────────────────────────────────────────────────────────

module "alb" {
  source = "../../modules/alb"

  environment       = "prod"
  vpc_id            = module.vpc.vpc_id
  public_subnet_ids = module.vpc.public_subnet_ids
  certificate_arn   = module.dns.certificate_arn
}

# ─────────────────────────────────────────────────────────────
# ECS Cluster (shared infrastructure)
# ─────────────────────────────────────────────────────────────

module "ecs_cluster" {
  source = "../../modules/ecs-cluster"

  environment = "prod"
  vpc_id      = module.vpc.vpc_id
  secret_arns = [module.rds.password_secret_arn]
}

# ─────────────────────────────────────────────────────────────
# ECS Services (each uses the reusable ecs-service module)
# ─────────────────────────────────────────────────────────────

module "nats" {
  source = "../../modules/ecs-service"

  environment        = "prod"
  name               = "nats"
  cluster_id         = module.ecs_cluster.cluster_id
  image              = "nats:2.10-alpine"
  cpu                = 256
  memory             = 512
  desired_count      = 1
  subnet_ids         = module.vpc.private_subnet_ids
  security_group_ids = [module.ecs_cluster.security_group_id]
  execution_role_arn = module.ecs_cluster.execution_role_arn
  aws_region         = var.aws_region

  command       = ["--jetstream", "--store_dir", "/data", "--http_port", "8222"]
  port_mappings = [4222, 8222]

  readonly_root_filesystem = false
  enable_circuit_breaker   = false

  enable_service_discovery        = true
  service_discovery_namespace_id  = module.ecs_cluster.service_discovery_namespace_id
}

module "api" {
  source = "../../modules/ecs-service"

  environment        = "prod"
  name               = "api"
  cluster_id         = module.ecs_cluster.cluster_id
  image              = var.api_image
  cpu                = 512
  memory             = 1024
  desired_count      = 2
  subnet_ids         = module.vpc.private_subnet_ids
  security_group_ids = [module.ecs_cluster.security_group_id]
  execution_role_arn = module.ecs_cluster.execution_role_arn
  task_role_arn      = module.ecs_cluster.task_role_arn
  aws_region         = var.aws_region

  port_mappings = [8080]

  environment_variables = [
    { name = "PORT", value = "8080" },
    { name = "NATS_URL", value = "nats://nats.prod.trading.local:4222" },
    { name = "DATABASE_URL", value = "postgres://${module.rds.username}:PLACEHOLDER@${module.rds.address}/${module.rds.db_name}?sslmode=require" }
  ]

  secrets = [{ name = "DB_PASSWORD", valueFrom = module.rds.password_secret_arn }]

  target_group_arn       = module.alb.target_group_arn
  enable_circuit_breaker = true
}

module "worker" {
  source = "../../modules/ecs-service"

  environment        = "prod"
  name               = "worker"
  cluster_id         = module.ecs_cluster.cluster_id
  image              = var.worker_image
  cpu                = 512
  memory             = 1024
  desired_count      = 2
  subnet_ids         = module.vpc.private_subnet_ids
  security_group_ids = [module.ecs_cluster.security_group_id]
  execution_role_arn = module.ecs_cluster.execution_role_arn
  task_role_arn      = module.ecs_cluster.task_role_arn
  aws_region         = var.aws_region

  environment_variables = [
    { name = "NATS_URL", value = "nats://nats.prod.trading.local:4222" },
    { name = "DATABASE_URL", value = "postgres://${module.rds.username}:PLACEHOLDER@${module.rds.address}/${module.rds.db_name}?sslmode=require" }
  ]

  secrets = [{ name = "DB_PASSWORD", valueFrom = module.rds.password_secret_arn }]

  enable_circuit_breaker = true
}

# ─────────────────────────────────────────────────────────────
# Observability
# ─────────────────────────────────────────────────────────────

module "observability" {
  source = "../../modules/observability"

  environment                 = "prod"
  alb_arn_suffix              = module.alb.alb_arn_suffix
  api_target_group_arn_suffix = module.alb.target_group_arn_suffix
  ecs_cluster_name            = module.ecs_cluster.cluster_name
  api_service_name            = module.api.service_name
  worker_service_name         = module.worker.service_name
  rds_instance_id             = "prod-trading-db"
  alarm_email                 = var.alarm_email
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
