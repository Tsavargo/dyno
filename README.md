# DYNO the Dynamic Serverless Function Compositor

DYNO deploys a serverless pipeline to AWS — Lambda functions, an S3 cache
bucket, and a Step Functions state machine — all from a single JSON config.

## Quick Start

```bash
# 1. Configure AWS credentials (one-time)
aws configure

# 2. Deploy everything
make deploy
```

That's it. `deploy.sh` auto-detects your AWS account ID and region, installs
Python dependencies, generates Lambda orchestrators and the Step Functions
workflow, then deploys everything via Terraform.

## Requirements

| Tool       | Purpose                          |
| ---------- | -------------------------------- |
| `python3`  | Run generator scripts            |
| `pip`      | Install Python dependencies      |
| `terraform`| Provision AWS infrastructure     |
| `jq`       | Parse JSON in the deploy script  |
| `aws` CLI  | AWS credentials & authentication |

The IAM role **LabRole** must already exist in your AWS account (standard in
AWS Academy / Learner Labs).

## Make Targets

| Target    | What it does                                     |
| --------- | ------------------------------------------------ |
| `deploy`  | Run the full deployment pipeline (default)       |
| `setup`   | Create `.env` from template, install deps, init  |
| `clean`   | Remove generated code and build artifacts        |
| `destroy` | Tear down all AWS infrastructure                 |

## Configuration (optional)

Copy `.env.example` to `.env` if you need to override any defaults:

```bash
cp .env.example .env
```

Everything has sensible defaults and AWS values are auto-detected — you only
need `.env` to customise project paths or override auto-detection.
