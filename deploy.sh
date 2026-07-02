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
  die ".env file not found: $ENV_FILE\n        Please copy the example and fill it in: cp .env.example .env"
fi

# shellcheck source=/dev/null
source "$ENV_FILE"

# ── Derived Variables ─────────────────────────────────────────────────────────

# The orchestrator generator places composite packages under output_dir/composites
COMPOSITES_DIR="${OUTPUT_DIR%/}/composites"

# Output path for the rendered ASL (State Machine) file
ASL_OUTPUT_FILE="${OUTPUT_DIR%/}/workflow.json"

# Absolute versions of all paths passed to Terraform and Python scripts
ABS_COMPOSITES_DIR="$(abs_path "$COMPOSITES_DIR")"
ABS_ASL_OUTPUT_FILE="$(abs_path "$ASL_OUTPUT_FILE")"
ABS_DYNO_REQUIREMENTS="$(abs_path "${DYNO_REQUIREMENTS_FILE:-python/dyno/requirements.txt}")"
ABS_DYNO_LAYER_SOURCE="$(abs_path "${DYNO_LAYER_SOURCE_DIR:-"."}")"
ABS_TERRAFORM_DIR="$(abs_path "$TERRAFORM_DIR")"

# ── Prerequisites Check ───────────────────────────────────────────────────────

step "System Checks & Prerequisites"

for cmd in python3 terraform jq; do
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
