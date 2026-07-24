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
# ECS Cluster (shared infrastructure)
# ─────────────────────────────────────────────────────────────

module "ecs_cluster" {
  source = "../../modules/ecs-cluster"

  environment = "dev"
  vpc_id      = module.vpc.vpc_id
  secret_arns = [module.rds.password_secret_arn]
}

# ─────────────────────────────────────────────────────────────
# ECS Services (each uses the reusable ecs-service module)
# ─────────────────────────────────────────────────────────────

module "nats" {
  source = "../../modules/ecs-service"

  environment        = "dev"
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

  environment        = "dev"
  name               = "api"
  cluster_id         = module.ecs_cluster.cluster_id
  image              = var.api_image
  cpu                = 256
  memory             = 512
  desired_count      = 1
  subnet_ids         = module.vpc.private_subnet_ids
  security_group_ids = [module.ecs_cluster.security_group_id]
  execution_role_arn = module.ecs_cluster.execution_role_arn
  task_role_arn      = module.ecs_cluster.task_role_arn
  aws_region         = var.aws_region

  port_mappings = [8080]

  environment_variables = [
    { name = "PORT", value = "8080" },
    { name = "NATS_URL", value = "nats://nats.dev.trading.local:4222" },
    { name = "DATABASE_URL", value = "postgres://${module.rds.username}:PLACEHOLDER@${module.rds.address}/${module.rds.db_name}?sslmode=require" }
  ]

  secrets = [{ name = "DB_PASSWORD", valueFrom = module.rds.password_secret_arn }]

  target_group_arn       = module.alb.target_group_arn
  enable_circuit_breaker = true
}

module "worker" {
  source = "../../modules/ecs-service"

  environment        = "dev"
  name               = "worker"
  cluster_id         = module.ecs_cluster.cluster_id
  image              = var.worker_image
  cpu                = 256
  memory             = 512
  desired_count      = 1
  subnet_ids         = module.vpc.private_subnet_ids
  security_group_ids = [module.ecs_cluster.security_group_id]
  execution_role_arn = module.ecs_cluster.execution_role_arn
  task_role_arn      = module.ecs_cluster.task_role_arn
  aws_region         = var.aws_region

  environment_variables = [
    { name = "NATS_URL", value = "nats://nats.dev.trading.local:4222" },
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

  environment                 = "dev"
  alb_arn_suffix              = module.alb.alb_arn_suffix
  api_target_group_arn_suffix = module.alb.target_group_arn_suffix
  ecs_cluster_name            = module.ecs_cluster.cluster_name
  api_service_name            = module.api.service_name
  worker_service_name         = module.worker.service_name
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
