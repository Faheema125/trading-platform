# Trading Platform

A minimal order processing service deployed on AWS ECS Fargate, with full infrastructure as code.

## Overview

This platform runs a simple trading order service:
- **API** — accepts and retrieves orders via HTTP
- **Worker** — processes orders asynchronously via NATS

## Architecture

```
Client → ALB (HTTPS) → API (ECS Fargate) → Postgres (RDS)
                                          → NATS → Worker (ECS Fargate) → Postgres
```

## Project Structure

```
├── app/                  # Go application code
│   ├── cmd/api/          # HTTP API server
│   ├── cmd/worker/       # Queue consumer
│   └── internal/         # Shared packages
├── docker/               # Dockerfiles
├── infra/                # Terraform
│   ├── modules/          # Reusable infrastructure modules
│   └── environments/     # Environment-specific configs (dev, prod)
├── .github/workflows/    # CI/CD pipelines
└── docs/                 # Evidence and documentation
```

## Getting Started

Prerequisites:
- Go 1.22+
- Docker
- Terraform 1.7+
- AWS CLI configured
- A domain with DNS you control (for TLS)

### Local Development

```bash
# Start dependencies
docker compose up -d

# Run the API
cd app && go run ./cmd/api

# Run the worker
cd app && go run ./cmd/worker
```

### Deploy

See the CI/CD section below for automated deployment via GitHub Actions.

## Status

🚧 Under construction
