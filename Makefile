# ==============================================================================
# DYNO -- Makefile
# ==============================================================================
# Targets:
#   deploy  -- Full deployment pipeline (default)
#   setup   -- Create .env from template, install Python deps, init Terraform
#   clean   -- Remove generated code and build artifacts
#   destroy -- Tear down all AWS infrastructure
# ==============================================================================

.PHONY: setup deploy clean destroy

# ── Default target ────────────────────────────────────────────────────────────

deploy:
	./deploy.sh

# ── Setup ─────────────────────────────────────────────────────────────────────

setup:
	@if [ ! -f .env ]; then \
		echo "[INFO] Creating .env from .env.example..."; \
		cp .env.example .env; \
		echo "[INFO] .env created. Edit it if you need to override defaults."; \
	else \
		echo "[INFO] .env already exists. Skipping."; \
	fi
	pip3 install -q -r requirements.txt 2>/dev/null || pip install -q -r requirements.txt
	cd source/terraform && terraform init -input=false > /dev/null 2>&1 && echo "[INFO] Terraform initialized."

# ── Clean ─────────────────────────────────────────────────────────────────────

clean:
	rm -rf output/
	rm -rf source/terraform/build_zips/
	rm -rf source/terraform/layer_staging/

# ── Destroy ───────────────────────────────────────────────────────────────────

destroy:
	@if [ ! -d source/terraform/.terraform ]; then \
		echo "[WARN] No Terraform state found. Nothing to destroy."; \
	else \
		cd source/terraform && terraform destroy -auto-approve; \
	fi
