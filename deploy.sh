#!/usr/bin/env bash
# ==============================================================================
# deploy.sh – Full Dyno Deployment Pipeline
# ==============================================================================
# This script orchestrates the entire deployment process:
#   1. Generates composite Lambda orchestrators (Python).
#   2. Runs a targeted Terraform apply (provisions S3 & Lambdas ONLY).
#   3. Extracts the dynamically generated S3 bucket name.
#   4. Generates the Step Functions ASL file injected with AWS variables.
#   5. Runs a full Terraform apply to deploy the State Machine.
# ==============================================================================

set -euo pipefail

# ── Colors & Formatting ───────────────────────────────────────────────────────

readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly YELLOW='\033[1;33m'
readonly NC='\033[0m' # No Color

# ── Helper Functions ──────────────────────────────────────────────────────────

log()  { echo -e "${GREEN}[$(date '+%H:%M:%S')]${NC} $*"; }
info() { echo -e "${CYAN}[INFO]${NC} $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
die()  { echo -e "${RED}[ERROR] $*${NC}" >&2; exit 1; }

step() {
  echo -e "\n${BLUE}════════════════════════════════════════════════════════════════════════${NC}"
  echo -e "${BLUE}▶ $*${NC}"
  echo -e "${BLUE}════════════════════════════════════════════════════════════════════════${NC}"
}

# Return an absolute path: if the input already starts with /, use it as-is,
# otherwise resolve it relative to SCRIPT_DIR.
abs_path() {
  local p="$1"
  if [[ "$p" = /* ]]; then
    echo "$p"
  else
    echo "${SCRIPT_DIR}/${p}"
  fi
}

# ── Load Configuration ────────────────────────────────────────────────────────

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${SCRIPT_DIR}/.env"

if [[ ! -f "$ENV_FILE" ]]; then
  warn ".env file not found. Using built-in defaults."
  warn "To customize, copy .env.example to .env:  cp .env.example .env"
else
  # shellcheck source=/dev/null
  source "$ENV_FILE"
fi

# ── Default project configuration ─────────────────────────────────────────────
# Every value below can be overridden by .env. These are the built-in defaults.

CONFIG_FILE="${CONFIG_FILE:-schema/stream-composite.json}"
SOURCE_DIR="${SOURCE_DIR:-source/functions/}"
OUTPUT_DIR="${OUTPUT_DIR:-output/}"
TEMPLATE_FILE="${TEMPLATE_FILE:-source/orchestrator_template.py.j2}"
ASL_TEMPLATE_FILE="${ASL_TEMPLATE_FILE:-source/asl_template.asl.j2}"
ORCHESTRATOR_SCRIPT="${ORCHESTRATOR_SCRIPT:-source/orchestrator_generator.py}"
ASL_SCRIPT="${ASL_SCRIPT:-source/asl_generator.py}"
TERRAFORM_DIR="${TERRAFORM_DIR:-source/terraform/}"
DYNO_REQUIREMENTS_FILE="${DYNO_REQUIREMENTS_FILE:-source/python/dyno/requirements.txt}"
DYNO_LAYER_SOURCE_DIR="${DYNO_LAYER_SOURCE_DIR:-source/python/dyno/}"

# ── Auto-detect AWS values ────────────────────────────────────────────────────

if [[ -z "${AWS_ACCOUNT_ID:-}" ]]; then
  info "AWS_ACCOUNT_ID not set. Auto-detecting via AWS CLI..."
  AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text 2>/dev/null) \
    || die "Could not auto-detect AWS account ID. Either configure AWS CLI (aws configure) or set AWS_ACCOUNT_ID in .env"
  log "Auto-detected AWS Account ID: ${YELLOW}$AWS_ACCOUNT_ID${NC}"
fi

if [[ -z "${AWS_REGION:-}" ]]; then
  AWS_REGION=$(aws configure get region 2>/dev/null) || true
  if [[ -z "$AWS_REGION" ]]; then
    AWS_REGION="us-east-1"
    info "No region found in AWS CLI config. Defaulting to us-east-1."
  else
    log "Auto-detected AWS Region: ${YELLOW}$AWS_REGION${NC}"
  fi
fi

# ── Derived Variables ─────────────────────────────────────────────────────────

# The orchestrator generator places composite packages under output_dir/composites
COMPOSITES_DIR="${OUTPUT_DIR%/}/composites"

# Output path for the rendered ASL (State Machine) file
ASL_OUTPUT_FILE="${OUTPUT_DIR%/}/workflow.json"

# Absolute versions of all paths passed to Terraform and Python scripts
ABS_COMPOSITES_DIR="$(abs_path "$COMPOSITES_DIR")"
ABS_ASL_OUTPUT_FILE="$(abs_path "$ASL_OUTPUT_FILE")"
ABS_DYNO_REQUIREMENTS="$(abs_path "$DYNO_REQUIREMENTS_FILE")"
ABS_DYNO_LAYER_SOURCE="$(abs_path "$DYNO_LAYER_SOURCE_DIR")"
ABS_TERRAFORM_DIR="$(abs_path "$TERRAFORM_DIR")"

# ── Prerequisites Check ───────────────────────────────────────────────────────

step "System Checks & Prerequisites"

for cmd in python3 terraform jq aws; do
  if ! command -v "$cmd" &>/dev/null; then
    die "'$cmd' is required but not found in PATH."
  fi
  log "Found dependency: $cmd"
done

# Verify all required files and directories exist
[[ -f "$(abs_path "$CONFIG_FILE")" ]]         || die "Config file not found: $CONFIG_FILE"
[[ -d "$(abs_path "$SOURCE_DIR")" ]]          || die "Source directory not found: $SOURCE_DIR"
[[ -f "$(abs_path "$TEMPLATE_FILE")" ]]       || die "Python template not found: $TEMPLATE_FILE"
[[ -f "$(abs_path "$ASL_TEMPLATE_FILE")" ]]   || die "ASL template not found: $ASL_TEMPLATE_FILE"
[[ -f "$(abs_path "$ORCHESTRATOR_SCRIPT")" ]] || die "Orchestrator script not found: $ORCHESTRATOR_SCRIPT"
[[ -f "$(abs_path "$ASL_SCRIPT")" ]]          || die "ASL script not found: $ASL_SCRIPT"
[[ -d "$ABS_TERRAFORM_DIR" ]]                 || die "Terraform directory not found: $TERRAFORM_DIR"

info "All prerequisites satisfied."

# ── Install Python Dependencies ───────────────────────────────────────────────

step "Python Dependencies"

info "Installing project Python dependencies..."
pip3 install -q -r "${SCRIPT_DIR}/requirements.txt" 2>/dev/null \
  || pip install -q -r "${SCRIPT_DIR}/requirements.txt" 2>/dev/null \
  || die "Failed to install Python dependencies. Ensure pip is available."
log "Python dependencies installed."

# ── Validate AWS Credentials ──────────────────────────────────────────────────

info "Validating AWS credentials..."
aws sts get-caller-identity --output text > /dev/null 2>&1 \
  || die "AWS credentials are not configured or have expired. Run 'aws configure' first."
log "AWS credentials validated. Account: ${YELLOW}$AWS_ACCOUNT_ID${NC}"

# ── Step 1: Generate Orchestrators ────────────────────────────────────────────

step "1/4 · Generating Lambda Orchestrators"

mkdir -p "$(abs_path "$OUTPUT_DIR")"

info "Executing: python3 $(basename "$ORCHESTRATOR_SCRIPT")"
python3 "$(abs_path "$ORCHESTRATOR_SCRIPT")" \
  --config   "$(abs_path "$CONFIG_FILE")" \
  --source   "$(abs_path "$SOURCE_DIR")" \
  --output   "$(abs_path "$COMPOSITES_DIR")" \
  --template "$(abs_path "$TEMPLATE_FILE")"

[[ -d "$ABS_COMPOSITES_DIR" ]] || die "Generator failed to create: $ABS_COMPOSITES_DIR"
log "Composites successfully generated at: $ABS_COMPOSITES_DIR"

# ── Step 2: Targeted Terraform Apply (S3 + Lambda) ────────────────────────────

step "2/4 · Initializing Infrastructure (Targeted Apply)"
info "Deploying S3 Data Bucket and Lambda Functions (excluding State Machine)"

cd "$ABS_TERRAFORM_DIR"

info "Running terraform init..."
terraform init -input=false > /dev/null

info "Running targeted terraform apply..."
terraform apply \
  -input=false \
  -auto-approve \
  -var "composites_dir=${ABS_COMPOSITES_DIR}" \
  -var "asl_file=/dev/null" \
  -var "dyno_requirements_file=${ABS_DYNO_REQUIREMENTS}" \
  -var "dyno_layer_source_dir=${ABS_DYNO_LAYER_SOURCE}" \
  -target="aws_s3_bucket.lambda_data_bucket" \
  -target="aws_lambda_layer_version.dyno_layer" \
  -target="aws_lambda_function.dynamic_lambdas"

log "Targeted infrastructure deployed successfully."

# ── Step 3: Extract S3 Bucket Name ────────────────────────────────────────────

step "3/4 · Extracting Dynamic Outputs"

BUCKET_NAME=$(terraform output -raw data_bucket_name 2>/dev/null) \
  || die "Failed to extract 'data_bucket_name' from Terraform state."

[[ -n "$BUCKET_NAME" ]] || die "S3 bucket name returned empty."
log "Resolved S3 Cache Bucket: ${YELLOW}$BUCKET_NAME${NC}"

cd "$SCRIPT_DIR"

# ── Step 4a: Generate ASL ─────────────────────────────────────────────────────

step "4a/4 · Generating Step Functions ASL Definition"

info "Executing: python3 $(basename "$ASL_SCRIPT")"
python3 "$(abs_path "$ASL_SCRIPT")" \
  --json     "$(abs_path "$CONFIG_FILE")" \
  --template "$(abs_path "$ASL_TEMPLATE_FILE")" \
  --output   "$ABS_ASL_OUTPUT_FILE" \
  --bucket   "$BUCKET_NAME" \
  --region   "$AWS_REGION" \
  --account  "$AWS_ACCOUNT_ID"

[[ -f "$ABS_ASL_OUTPUT_FILE" ]] || die "ASL generator failed to create: $ABS_ASL_OUTPUT_FILE"
log "Workflow definition generated at: $ABS_ASL_OUTPUT_FILE"

# ── Step 4b: Full Terraform Apply ─────────────────────────────────────────────

step "4b/4 · Finalizing Infrastructure (Full Stack Apply)"
info "Deploying Step Functions State Machine"

cd "$ABS_TERRAFORM_DIR"

info "Running full terraform apply..."
terraform apply \
  -input=false \
  -auto-approve \
  -var "composites_dir=${ABS_COMPOSITES_DIR}" \
  -var "asl_file=${ABS_ASL_OUTPUT_FILE}" \
  -var "dyno_requirements_file=${ABS_DYNO_REQUIREMENTS}" \
  -var "dyno_layer_source_dir=${ABS_DYNO_LAYER_SOURCE}"

cd "$SCRIPT_DIR"

# ── Summary ───────────────────────────────────────────────────────────────────

step "Deployment Completed Successfully!"

STATE_MACHINE_ARN=$(cd "$ABS_TERRAFORM_DIR" && terraform output -raw state_machine_arn 2>/dev/null || echo "n/a")

echo -e "  ${CYAN}S3 Cache Bucket:${NC}    $BUCKET_NAME"
echo -e "  ${CYAN}ASL Definition:${NC}     $ABS_ASL_OUTPUT_FILE"
echo -e "  ${CYAN}State Machine ARN:${NC}  ${YELLOW}$STATE_MACHINE_ARN${NC}"
echo ""
log "All systems go."
