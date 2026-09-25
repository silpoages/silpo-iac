# silpo-iac

Infrastructure as Code for the Silpo project on AWS, using **OpenTofu** (reusable modules,
Terraform-compatible HCL) + **Terragrunt** (environment wiring, remote state, DRY provider
config — Terragrunt 1.x runs OpenTofu by default).

> Traffic assumption driving every default here: at most 3-4 concurrent users, and close to zero
> traffic for ~99% of the day. Every choice below optimizes for that — see
> [Cost trade-offs](#cost-trade-offs).

## Stack

| Layer               | Technology                                      |
| ------------------- | ------------------------------------------------ |
| IaC                 | OpenTofu + Terragrunt                            |
| Cloud               | AWS                                              |
| Compute             | ECS Fargate (single task) + Application Load Balancer |
| Database            | RDS PostgreSQL (single-AZ, `db.t4g.micro`)       |
| Container registry  | ECR                                              |
| Secrets             | AWS Secrets Manager                              |
| Linting             | `tofu fmt`, `terragrunt hcl fmt`, TFLint         |
| Security scanning   | tfsec                                            |
| Pre-commit hooks    | [pre-commit](https://pre-commit.com) + pre-commit-terraform |
| CI                  | GitHub Actions                                   |

## Repository layout

```
terraform/
  modules/
    networking/    # VPC, public/private subnets, optional NAT gateway
    ecr/            # Container registry for the silpo-backend image
    rds-postgres/   # RDS instance + Secrets Manager secret with connection details
    ecs-service/    # ECS cluster, Fargate service, ALB, task's own app secrets (JWT/Resend)
terragrunt/
  terragrunt.hcl    # Root config: S3 remote state (native locking) + AWS provider generation
  live/
    shared/         # The one environment this project runs (see "Environments" below)
      env.hcl       # account_id / aws_region / environment name
      networking/
      ecr/
      rds/
      api/
```

## Environments

This project runs a **single environment** (`shared`), not separate `dev`/`staging`/`prod` stacks.
Running a full second copy (ALB + RDS + Fargate) would roughly double the fixed monthly cost for
a project with this little traffic, so it wasn't worth it. If that changes (e.g. real users,
need for a safe place to test destructive changes), copy `terragrunt/live/shared/` to a new
`terragrunt/live/<name>/` folder with its own `env.hcl` — every module already supports it.

## Cost trade-offs

Defaults here explicitly trade a bit of resilience/observability for a lower, mostly-fixed bill:

- **No NAT gateway** (`enable_nat_gateway = false` in `networking`). A NAT gateway costs ~US$32-38/month
  just sitting idle — often more than the rest of this stack combined at this traffic level. Instead,
  the ECS Fargate task runs in the **public** subnets with a public IP (`assign_public_ip = true` in
  the `api` unit). This does *not* expose the app directly: the task's security group only allows
  inbound traffic from the ALB's security group, so a public IP on the task doesn't make it reachable
  from the internet. RDS stays in the private subnets and never needs outbound internet access, so it
  doesn't need NAT either.
- **Single-AZ RDS**, `db.t4g.micro`, no read replica. Enough for a handful of users; `multi_az = true`
  would double the RDS cost for redundancy this project doesn't need yet.
- **Smallest Fargate task** (256 CPU units / 512 MiB), `desired_count = 1`. No autoscaling — one task
  is enough for a handful of concurrent users, and it's the cheapest way to keep the API always
  reachable (Fargate bills per second while running, so this is the actual cost floor, not a burst
  limit).
- **Container Insights disabled** by default (`enable_container_insights = false` in `ecs-service`) —
  it adds CloudWatch metrics cost for observability this project doesn't need day to day.

**Rough always-on monthly estimate** (`us-east-1`, on-demand pricing, excluding AWS free tier which
likely covers most of this in year one): ALB ~US$18 (fixed) + RDS ~US$15 (instance + storage) +
Fargate ~US$9 (1 task, 256/512) + Secrets Manager/CloudWatch/ECR ~US$2 ≈ **US$40-45/month**, dominated
by the ALB.

**If you need to go lower than that**: the only way to actually get near US$0 during idle hours is to
stop running the API 24/7 — e.g. port `silpo-backend` to run on AWS Lambda (behind API Gateway
instead of an ALB, using an ASGI adapter like [Mangum](https://github.com/jordaneremieff/mangum)) so
you pay per request instead of per second of uptime. That's a `silpo-backend` code change, not just
infra, so it's deliberately out of scope here — flag it if the AWS bill becomes worth optimizing
further.

## Prerequisites

- [OpenTofu](https://opentofu.org/docs/intro/install/) `>= 1.7` (Terragrunt invokes `tofu` by
  default; a Terraform CLI install works too, but then pass `--tf-path terraform` to every
  Terragrunt command)
- [Terragrunt](https://terragrunt.gruntwork.io/docs/getting-started/install/) `>= 1.0`
- [TFLint](https://github.com/terraform-linters/tflint) (optional locally, runs in CI)
- AWS credentials with permission to create the resources in `terraform/modules/*`

## One-time bootstrap

1. **Set the real AWS account ID.** Edit `terragrunt/live/shared/env.hcl` and replace the
   placeholder `account_id`. This namespaces the Terraform state bucket
   (`silpo-terraform-state-<account_id>`) so it doesn't collide with anyone else's AWS account.
2. **Set the real Resend API key.** Terraform can't invent a real third-party API key, so it's
   not a committed input:
   ```bash
   cp terragrunt/live/shared/api/secrets.tfvars.example terragrunt/live/shared/api/secrets.tfvars
   ```
   Edit `secrets.tfvars` (git-ignored) and fill in the real key. Skipping this step is fine —
   `resend_api_key` defaults to an empty string — but email sending won't work until it's set
   and the `api` unit is re-applied.
3. **Apply.** The `--backend-bootstrap` flag has Terragrunt create the S3 state bucket
   automatically if it doesn't exist yet (state locking uses S3's own native locking, no
   DynamoDB table needed) — no separate bootstrap step:
   ```bash
   cd terragrunt/live/shared
   terragrunt apply --all --backend-bootstrap
   ```
   Terragrunt resolves the dependency order itself: `networking` → `ecr`/`rds` → `api`.
4. **Push an image.** The `ecr` unit's output (`repository_url`) is where `silpo-backend`'s CI
   should push images. The `api` unit currently deploys the `:latest` tag; wiring a real
   build-and-deploy pipeline in `silpo-backend` is a natural next step.

## CI/CD

`.github/workflows/ci.yml` runs on every push and pull request:

- **Lint** — `tofu fmt -check`, `terragrunt hcl fmt --check`, TFLint
- **Test** — `tofu validate` per module (no AWS credentials needed) + `tfsec` security scan
- **Build** — `terragrunt plan --all` against real AWS, via OIDC (no long-lived AWS keys in
  GitHub). **Skipped until configured** — set these to enable it:
  - Repo variable `AWS_ROLE_ARN`: an IAM role GitHub Actions can assume via OIDC
    (`token.actions.githubusercontent.com` as the trusted identity provider, scoped to this repo).
  - Repo variable `AWS_REGION` (optional, defaults to `us-east-1`).

  A skipped required check still counts as passing for branch protection, so PRs aren't blocked
  in the meantime — `Build` just does nothing useful yet.

All three (`Lint`, `Test`, `Build`) are required status checks on `main` and `develop`, matching
`silpo-backend`'s branch protection.

## Conventions

Same as `silpo-backend`: `<tipo>/<descricao>` branches in `kebab-case`, Conventional Commits,
`[TIPO] Descrição objetiva` PR titles, PRs against `develop`.
