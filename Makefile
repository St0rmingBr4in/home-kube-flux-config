.DEFAULT_GOAL := help
.PHONY: help install-hooks \
        pre-commit kustomize-validate terraform-fmt \
        lint lint-shell lint-go lint-ansible lint-terraform \
        ci-report \
        terraform-init terraform-plan terraform-apply \
        terraform-authentik-init terraform-authentik-plan terraform-authentik-apply \
        terraform-tfe-init terraform-tfe-plan terraform-tfe-apply \
        terraform-datadog-init terraform-datadog-plan terraform-datadog-apply \
        terraform-digitalocean-init terraform-digitalocean-plan terraform-digitalocean-apply \
        terraform-tailscale-init terraform-tailscale-plan terraform-tailscale-apply \
        terraform-vault-init terraform-vault-plan terraform-vault-apply \
        ansible-install-inlet ansible-install-k3s \
        ansible-setup-ssh-inlet ansible-setup-ssh-k3s \
        ansible-install-edgerouter \
        ansible-setup-ssh-edgerouter \
        ansible-edgerouter ansible-edgerouter-check \
        ansible-inlet ansible-inlet-check \
        ansible-k3s ansible-k3s-check \
        memory-webhook-test \

ANSIBLE_FLAGS  ?=
TF_AUTHENTIK_DIR    := terraform/authentik
TF_DIR              := $(TF_AUTHENTIK_DIR)
TF_TFE_DIR          := terraform/tfe
TF_DATADOG_DIR      := terraform/datadog
TF_DIGITALOCEAN_DIR := terraform/digitalocean
TF_TAILSCALE_DIR    := terraform/tailscale
TF_VAULT_DIR        := terraform/vault
DD_SITE        ?= datadoghq.eu

# ── Help ─────────────────────────────────────────────────────────────────────

help: ## Show available targets
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) \
		| awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-28s\033[0m %s\n", $$1, $$2}'

# ── Hooks ────────────────────────────────────────────────────────────────────

install-hooks: ## Install git hooks (run once after cloning)
	@printf '#!/bin/sh\nmake pre-commit\n' > .git/hooks/pre-commit
	@chmod +x .git/hooks/pre-commit
	@echo "Installed .git/hooks/pre-commit"

# ── Pre-commit ───────────────────────────────────────────────────────────────

pre-commit: kustomize-validate terraform-fmt lint-shell ## Run all pre-commit checks

kustomize-validate: ## Validate all kustomization files with kubectl kustomize
	@echo "==> Validating kustomizations"
	@find argocd/applications -name "kustomization.yaml" | while read f; do \
		kubectl kustomize "$$(dirname $$f)" > /dev/null \
			&& echo "  ✓ $$f" \
			|| { echo "  ✗ $$f"; exit 1; }; \
	done

terraform-fmt: ## Check Terraform formatting across all modules (non-destructive)
	@echo "==> Checking Terraform format"
	@for dir in $(TF_DIR) $(TF_TFE_DIR) $(TF_DATADOG_DIR) $(TF_DIGITALOCEAN_DIR) $(TF_TAILSCALE_DIR) $(TF_VAULT_DIR); do \
		terraform -chdir=$$dir fmt -check -recursive || exit 1; \
	done

# ── Linting ───────────────────────────────────────────────────────────────────

lint: lint-shell lint-go lint-ansible lint-terraform ## Run all linters

lint-shell: ## Lint shell scripts with shellcheck
	@echo "==> Shellcheck"
	find ansible/scripts/ -name "*.sh" | xargs shellcheck

lint-go: ## Lint Go code with go vet and golangci-lint
	@echo "==> go vet"
	(cd memory-webhook && go vet ./...)
	@if [ -n "$(GITHUB_ACTIONS)" ]; then \
		echo "==> Installing golangci-lint"; \
		curl -sSfL https://raw.githubusercontent.com/golangci/golangci-lint/HEAD/install.sh \
			| sh -s -- -b "$$(go env GOPATH)/bin" latest; \
	fi
	@echo "==> golangci-lint"
	(cd memory-webhook && golangci-lint run ./...)

lint-ansible: ## Lint Ansible playbooks with ansible-lint
	@echo "==> ansible-lint"
	pip install ansible-lint --quiet
	ansible-galaxy role install -r ansible/requirements.yml --roles-path ansible/roles
	ansible-galaxy collection install -r ansible/requirements.yml
	cd ansible && ansible-lint

lint-terraform: ## Check Terraform formatting across all modules
	$(MAKE) terraform-fmt

# ── CI / Datadog ──────────────────────────────────────────────────────────────

ci-report: ## Report pipeline to Datadog CI Visibility (no-op outside GitHub Actions)
	@if [ -n "$(GITHUB_ACTIONS)" ]; then \
		echo "==> Reporting pipeline to Datadog CI Visibility"; \
		DATADOG_SITE=$(DD_SITE) npx --yes @datadog/datadog-ci@latest tag \
			--level pipeline \
			--tags "service:home-kube-flux-config,env:ci,team:st0rmingbr4in"; \
	fi

# ── Terraform: Authentik ──────────────────────────────────────────────────────

terraform-authentik-init: ## Initialise Authentik Terraform
	terraform -chdir=$(TF_AUTHENTIK_DIR) init

terraform-authentik-plan: ## Plan Authentik Terraform
	terraform -chdir=$(TF_AUTHENTIK_DIR) plan -parallelism=1

terraform-authentik-apply: ## Apply Authentik Terraform
	terraform -chdir=$(TF_AUTHENTIK_DIR) apply -auto-approve -parallelism=1

# Legacy aliases kept for backward compatibility
terraform-init: terraform-authentik-init
terraform-plan: terraform-authentik-plan
terraform-apply: terraform-authentik-apply

# ── Terraform: TFE workspaces ─────────────────────────────────────────────────

terraform-tfe-init: ## Initialise TFE workspace Terraform
	terraform -chdir=$(TF_TFE_DIR) init

terraform-tfe-plan: ## Plan TFE workspace Terraform
	terraform -chdir=$(TF_TFE_DIR) plan

terraform-tfe-apply: ## Apply TFE workspace Terraform
	terraform -chdir=$(TF_TFE_DIR) apply -auto-approve

# ── Terraform: Datadog ────────────────────────────────────────────────────────

terraform-datadog-init: ## Initialise Datadog Terraform
	terraform -chdir=$(TF_DATADOG_DIR) init

terraform-datadog-plan: ## Plan Datadog Terraform
	terraform -chdir=$(TF_DATADOG_DIR) plan

terraform-datadog-apply: ## Apply Datadog Terraform
	terraform -chdir=$(TF_DATADOG_DIR) apply -auto-approve

# ── Terraform: DigitalOcean ───────────────────────────────────────────────────

terraform-digitalocean-init: ## Initialise DigitalOcean Terraform
	terraform -chdir=$(TF_DIGITALOCEAN_DIR) init

terraform-digitalocean-plan: ## Plan DigitalOcean Terraform
	terraform -chdir=$(TF_DIGITALOCEAN_DIR) plan

terraform-digitalocean-apply: ## Apply DigitalOcean Terraform
	terraform -chdir=$(TF_DIGITALOCEAN_DIR) apply -auto-approve

# ── Terraform: Tailscale ──────────────────────────────────────────────────────

terraform-tailscale-init: ## Initialise Tailscale Terraform
	terraform -chdir=$(TF_TAILSCALE_DIR) init

terraform-tailscale-plan: ## Plan Tailscale Terraform
	terraform -chdir=$(TF_TAILSCALE_DIR) plan

terraform-tailscale-apply: ## Apply Tailscale Terraform
	terraform -chdir=$(TF_TAILSCALE_DIR) apply -auto-approve

# ── Terraform: Vault ──────────────────────────────────────────────────────────

terraform-vault-init: ## Initialise Vault Terraform
	terraform -chdir=$(TF_VAULT_DIR) init

terraform-vault-plan: ## Plan Vault Terraform
	terraform -chdir=$(TF_VAULT_DIR) plan

terraform-vault-apply: ## Apply Vault Terraform
	terraform -chdir=$(TF_VAULT_DIR) apply -auto-approve

# ── Ansible ───────────────────────────────────────────────────────────────────

ansible-install-edgerouter: ## Install Ansible + collections for the edgerouter playbook
	pip install ansible
	ansible-galaxy collection install -r ansible/requirements.yml

ansible-setup-ssh-edgerouter: ## Write EdgeRouter SSH key from EDGEROUTER_SSH_PRIVATE_KEY env var
	@mkdir -p ~/.ssh
	@printf '%s\n' "$${EDGEROUTER_SSH_PRIVATE_KEY}" > ~/.ssh/edgerouter_id_ed25519
	@chmod 600 ~/.ssh/edgerouter_id_ed25519
	@printf 'IdentityFile ~/.ssh/edgerouter_id_ed25519\n' >> ~/.ssh/config

ansible-edgerouter: ## Run edgerouter playbook (check+diff on PRs or CHECK_MODE=true)
	@if [ "$${CHECK_MODE:-}" = "true" ] || [ "$${GITHUB_EVENT_NAME:-}" = "pull_request" ]; then \
		cd ansible && ansible-playbook playbooks/edgerouter.yaml --check --diff $(ANSIBLE_FLAGS); \
	else \
		cd ansible && ansible-playbook playbooks/edgerouter.yaml $(ANSIBLE_FLAGS); \
	fi

ansible-edgerouter-check: ## Run edgerouter playbook in check/diff mode (local dev)
	CHECK_MODE=true $(MAKE) ansible-edgerouter

ansible-install-inlet: ## Install Ansible + collections for the inlet playbook
	pip install ansible
	ansible-galaxy collection install ansible.posix

ansible-install-k3s: ## Install Ansible + roles + collections for the k3s playbook
	pip install ansible
	ansible-galaxy role install -r ansible/requirements.yml --roles-path ansible/roles
	ansible-galaxy collection install -r ansible/requirements.yml

ansible-setup-ssh-inlet: ## Write inlet SSH key from INLET_SSH_PRIVATE_KEY env var
	@mkdir -p ~/.ssh
	@printf '%s\n' "$${INLET_SSH_PRIVATE_KEY}" > ~/.ssh/inlet_id_ed25519
	@chmod 600 ~/.ssh/inlet_id_ed25519
	@printf 'IdentityFile ~/.ssh/inlet_id_ed25519\n' >> ~/.ssh/config

ansible-setup-ssh-k3s: ## Write k3s SSH key from K3S_SSH_PRIVATE_KEY env var
	@mkdir -p ~/.ssh
	@printf '%s\n' "$${K3S_SSH_PRIVATE_KEY}" > ~/.ssh/k3s_id_ed25519
	@chmod 600 ~/.ssh/k3s_id_ed25519
	@printf 'Host *\n  IdentityFile ~/.ssh/k3s_id_ed25519\n  StrictHostKeyChecking no\n' >> ~/.ssh/config

ansible-inlet: ## Run inlet playbook (check+diff on PRs or CHECK_MODE=true)
	@EXTRA_VARS=""; \
	if [ -n "$${QBITTORRENT_TAILSCALE_IP:-}" ]; then \
		EXTRA_VARS="$$EXTRA_VARS -e qbittorrent_torrent_tailscale_ip=$${QBITTORRENT_TAILSCALE_IP}"; \
	fi; \
	if [ -n "$${TAILSCALE_AUTHKEY:-}" ]; then \
		EXTRA_VARS="$$EXTRA_VARS -e tailscale_authkey=$${TAILSCALE_AUTHKEY}"; \
	fi; \
	if [ "$${CHECK_MODE:-}" = "true" ] || [ "$${GITHUB_EVENT_NAME:-}" = "pull_request" ]; then \
		cd ansible && ansible-playbook playbooks/inlet.yaml --check --diff $$EXTRA_VARS $(ANSIBLE_FLAGS); \
	else \
		cd ansible && ansible-playbook playbooks/inlet.yaml $$EXTRA_VARS $(ANSIBLE_FLAGS); \
	fi

ansible-inlet-check: ## Run inlet playbook in check/diff mode (local dev)
	CHECK_MODE=true $(MAKE) ansible-inlet

ansible-k3s: ## Run k3s playbook (check+diff on PRs or CHECK_MODE=true)
	@if [ "$${CHECK_MODE:-}" = "true" ] || [ "$${GITHUB_EVENT_NAME:-}" = "pull_request" ]; then \
		cd ansible && ansible-playbook playbooks/k3s.yaml --check --diff $(ANSIBLE_FLAGS); \
	else \
		cd ansible && ansible-playbook playbooks/k3s.yaml $(ANSIBLE_FLAGS); \
	fi

ansible-k3s-check: ## Run k3s playbook in check/diff mode (local dev)
	CHECK_MODE=true $(MAKE) ansible-k3s

# ── Memory Webhook ────────────────────────────────────────────────────────────

memory-webhook-test: ## Run Go tests; uploads JUnit results to Datadog in CI
	go install gotest.tools/gotestsum@latest
	cd memory-webhook && go mod tidy
	cd memory-webhook && gotestsum --junitfile junit.xml --format pkgname ./...
	@if [ -n "$(GITHUB_ACTIONS)" ]; then \
		echo "==> Uploading test results to Datadog CI Visibility"; \
		DATADOG_SITE=$(DD_SITE) npx --yes @datadog/datadog-ci@latest junit upload \
			--service memory-webhook \
			--tags "runtime:go" \
			memory-webhook/junit.xml; \
	fi
