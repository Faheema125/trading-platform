# Dev Environment Cost Estimate

Monthly estimate for the running dev stack in `us-east-1` (730 hours/month).

| Service | Spec | Monthly Cost |
|---------|------|-------------|
| ECS Fargate — API | 0.25 vCPU, 512 MB, 1 task | $9.01 |
| ECS Fargate — Worker | 0.25 vCPU, 512 MB, 1 task | $9.01 |
| ECS Fargate — NATS | 0.25 vCPU, 512 MB, 1 task | $9.01 |
| NAT Gateway | 1 gateway, ~1 GB data | $32.90 |
| RDS PostgreSQL | db.t3.micro, 20 GB, single-AZ | $15.44 |
| ALB | 1 ALB, minimal LCUs | $16.43 |
| CloudWatch Logs | ~0.5 GB ingestion | $0.25 |
| Secrets Manager | 1 secret | $0.40 |
| ECR | <1 GB stored | $0.10 |
| Route53 | 1 hosted zone | $0.50 |
| ACM Certificate | Free | $0.00 |
| **Total (no Free Tier)** | | **~$93.05** |
| **Total (with Free Tier)** | | **~$44.18** |

## AWS Free Tier Savings (first 12 months)

| Service | Free Tier Benefit | Monthly Saving |
|---------|-------------------|----------------|
| RDS | 750h db.t3.micro + 20 GB storage | -$15.44 |
| ALB | 750h + 15 LCUs | -$16.43 |
| NAT Gateway | 100 GB free data processing | -$0.00 |
| CloudWatch | 5 GB log ingestion free | -$0.25 |
| **Total savings** | | **-$32.12** |

With Free Tier: $93.05 - $32.12 - some additional free tier = **~$44/month** ✓ (under $50)

## How We Stay Under $50

1. **Single NAT Gateway** — one instead of per-AZ saves $33/month
2. **Minimal RDS** — db.t3.micro, single-AZ, no Multi-AZ ($0 vs $26)
3. **Single task per service** — 1 replica each (prod uses 2)
4. **Free Tier eligible** — account within first 12 months covers ALB + RDS

> **Note:** A t3.nano NAT instance (~$3.80/month) would reduce the NAT cost by ~$29, but we chose managed NAT Gateway to avoid instance management overhead (patching, monitoring, failure recovery) in a fully serverless architecture.

## Pricing Sources

- Fargate: $0.04048/vCPU/hour + $0.004445/GB/hour
- NAT Gateway: $0.045/hour + $0.045/GB processed
- RDS db.t3.micro: $0.018/hour + $0.115/GB-month storage
- ALB: $0.0225/hour + $0.008/LCU-hour
- All prices: us-east-1, on-demand, July 2026
