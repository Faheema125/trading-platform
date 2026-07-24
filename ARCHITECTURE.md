# Architecture Decisions

## 1. NAT Gateway (Single in Dev, Per-AZ in Prod) over VPC Endpoints or NAT Instances

The requirement places tasks in private subnets with no public IPs, but they still need outbound internet access for ECR image pulls, Secrets Manager, and CloudWatch. We chose NAT Gateway over VPC Endpoints (which would need 5+ endpoints at ~$7/month each — more expensive and complex at this scale) and over self-managed NAT Instances (cheaper but a single point of failure requiring patching and monitoring). In dev we run a single NAT gateway to stay under budget; in prod we use one per AZ so a single-AZ failure doesn't cut off all outbound traffic.

## 2. Secrets Manager with Native ECS Injection over Environment Variables or SSM Parameter Store

Database credentials are stored in Secrets Manager and injected directly via the ECS task definition's `secrets` block — the container receives the value at runtime without it appearing in plaintext in Terraform state, task metadata, or `docker inspect`. We rejected passing credentials as environment variables (visible in ECS console and logs if accidentally printed) and SSM Parameter Store (lacks native ECS injection for SecureString without a custom entrypoint script). The tradeoff is $0.40/month per secret and a runtime dependency on Secrets Manager availability, but we gain rotation support without redeployment and a clean audit trail.

## 3. Rolling Deployment with Circuit Breaker over CodeDeploy Blue/Green

For zero-downtime deploys with automatic rollback, we use ECS rolling deployment (min healthy 100%, max 200%) with the built-in deployment circuit breaker. If new tasks fail health checks, ECS automatically rolls back to the previous version within seconds. We rejected CodeDeploy blue/green which offers canary and linear traffic shifting but introduces an additional service to manage, requires extra IAM policies, and adds deployment time for the traffic-shifting window. For a small service count where fast feedback matters more than gradual traffic control, the circuit breaker is simpler and faster.

## 4. Distroless Runtime with ALB-Only Health Checks over Alpine with Container Health Checks

For container hardening we use `gcr.io/distroless/static:nonroot` — no shell, no package manager, read-only root filesystem, running as non-root. This eliminates entire classes of post-exploitation attacks (no shell to spawn, no tools to download, no filesystem to write to). The consequence is that ECS container-level health checks (which require `wget` or `curl` inside the container) are impossible, so we rely solely on the ALB target group health check which probes `/health` from outside. We rejected Alpine (which would allow in-container health checks) because the security surface reduction of distroless outweighs the convenience of in-container debugging.

## 5. NATS on Fargate with Cloud Map Service Discovery over Sidecar or Dedicated EC2

NATS is the right fit for a trading platform — it delivers sub-millisecond pub/sub, uses a persistent TCP connection (no polling), and the same binary runs identically in local dev and production. We run NATS as its own Fargate task with AWS Cloud Map providing DNS-based service discovery (`nats.dev.trading.local`). We rejected running NATS as a sidecar in each task (wastes resources, complicates scaling independently) and running it on a dedicated EC2 instance (introduces instance management, patching, and SSH access we don't need). Cloud Map gives us automatic DNS updates when the NATS task restarts with a new IP, so the API and worker always find it without hardcoded addresses.
