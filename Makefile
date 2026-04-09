.DEFAULT_GOAL := help
.PHONY: help install-hooks \
        pre-commit kustomize-validate terraform-fmt \
        terraform-init terraform-plan terraform-apply \
        terraform-tfe-init terraform-tfe-plan terraform-tfe-apply \
        terraform-datadog-init terraform-datadog-plan terraform-datadog-apply \
        ansible-k3s ansible-k3s-check ansible-inlet ansible-inlet-check \
        memory-webhook-test

ANSIBLE_FLAGS  ?=
TF_DIR         := terraform/authentik
TF_TFE_DIR     := terraform/tfe
TF_DATADOG_DIR := terraform/datadog

# ── Help ─────────────────────────────────────────────────────────────────────

help: ## Show available targets
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) \
		| awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-25s\033[0m %s\n", $$1, $$2}'

# ── Hooks ────────────────────────────────────────────────────────────────────

install-hooks: ## Install git hooks (run once after cloning)
	@printf '#!/bin/sh\nmake pre-commit\n' > .git/hooks/pre-commit
	@chmod +x .git/hooks/pre-commit
	@echo "Installed .git/hooks/pre-commit"

# ── Pre-commit ───────────────────────────────────────────────────────────────

pre-commit: kustomize-validate terraform-fmt ## Run all pre-commit checks

kustomize-validate: ## Validate all kustomization files with kubectl kustomize
	@echo "==> Validating kustomizations"
	@find argocd/applications -name "kustomization.yaml" | while read f; do \
		kubectl kustomize "$$(dirname $$f)" > /dev/null \
			&& echo "  ✓ $$f" \
			|| { echo "  ✗ $$f"; exit 1; }; \
	done

terraform-fmt: ## Check Terraform formatting across all modules (non-destructive)
	@echo "==> Checking Terraform format"
	@for dir in $(TF_DIR) $(TF_TFE_DIR) $(TF_DATADOG_DIR); do \
		terraform -chdir=$$dir fmt -check -recursive || exit 1; \
	done

# ── Terraform: Authentik ──────────────────────────────────────────────────────

terraform-init: ## Initialise Authentik Terraform
	terraform -chdir=$(TF_DIR) init

terraform-plan: ## Plan Authentik Terraform
	terraform -chdir=$(TF_DIR) plan -parallelism=1

terraform-apply: ## Apply Authentik Terraform
	terraform -chdir=$(TF_DIR) apply -auto-approve -parallelism=1

# ── Terraform: TFE workspaces ─────────────────────────────────────────────────

terraform-tfe-init: ## Initialise TFE workspace Terraform
	terraform -chdir=$(TF_TFE_DIR) init

terraform-tfe-plan: ## Plan TFE workspace Terraform
	terraform -chdir=$(TF_TFE_DIR) plan -parallelism=1

terraform-tfe-apply: ## Apply TFE workspace Terraform
	terraform -chdir=$(TF_TFE_DIR) apply -auto-approve -parallelism=1

# ── Terraform: Datadog ────────────────────────────────────────────────────────

terraform-datadog-init: ## Initialise Datadog Terraform
	terraform -chdir=$(TF_DATADOG_DIR) init

terraform-datadog-plan: ## Plan Datadog Terraform
	terraform -chdir=$(TF_DATADOG_DIR) plan -parallelism=1

terraform-datadog-apply: ## Apply Datadog Terraform
	terraform -chdir=$(TF_DATADOG_DIR) apply -auto-approve -parallelism=1

# ── Ansible ──────────────────────────────────────────────────────────────────

ansible-k3s: ## Run k3s playbook  (ANSIBLE_FLAGS=--check --diff for dry-run)
	cd ansible && ansible-playbook playbooks/k3s.yaml $(ANSIBLE_FLAGS)

ansible-k3s-check: ## Run k3s playbook in check/diff mode
	$(MAKE) ansible-k3s ANSIBLE_FLAGS="--check --diff"

ansible-inlet: ## Run inlet playbook  (ANSIBLE_FLAGS=--check --diff for dry-run)
	cd ansible && ansible-playbook playbooks/inlet.yaml $(ANSIBLE_FLAGS)

ansible-inlet-check: ## Run inlet playbook in check/diff mode
	$(MAKE) ansible-inlet ANSIBLE_FLAGS="--check --diff"

# ── Memory Webhook ───────────────────────────────────────────────────────────

memory-webhook-test: ## Run memory-webhook Go tests
	cd memory-webhook && go mod tidy && go test -v ./...
