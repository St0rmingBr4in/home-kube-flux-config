.DEFAULT_GOAL := help
.PHONY: help install-hooks \
        pre-commit kustomize-validate terraform-fmt \
        ci-report \
        terraform-init terraform-plan terraform-apply \
        terraform-tfe-init terraform-tfe-plan terraform-tfe-apply \
        terraform-datadog-init terraform-datadog-plan terraform-datadog-apply \
        ansible-install-inlet ansible-install-k3s \
        ansible-setup-ssh-inlet ansible-setup-ssh-k3s \
        ansible-inlet ansible-inlet-check \
        ansible-k3s ansible-k3s-check \
        memory-webhook-test \
        k3s-prepare k3s-wait-ready k3s-install-argocd k3s-configure-argocd \
        k3s-apply-apps k3s-validate-apps k3s-summary

ANSIBLE_FLAGS  ?=
TF_DIR         := terraform/authentik
TF_TFE_DIR     := terraform/tfe
TF_DATADOG_DIR := terraform/datadog
DD_SITE        ?= datadoghq.eu
# In GitHub Actions GITHUB_SHA is exported automatically; fall back to git locally.
COMMIT_SHA     ?= $(if $(GITHUB_SHA),$(GITHUB_SHA),$(shell git rev-parse HEAD))

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

# ── CI / Datadog ──────────────────────────────────────────────────────────────

ci-report: ## Report pipeline to Datadog CI Visibility (no-op outside GitHub Actions)
	@if [ -n "$(GITHUB_ACTIONS)" ]; then \
		echo "==> Reporting pipeline to Datadog CI Visibility"; \
		DATADOG_SITE=$(DD_SITE) npx --yes @datadog/datadog-ci@latest tag \
			--level pipeline \
			--tags "service:home-kube-flux-config,env:ci,team:st0rmingbr4in"; \
	fi

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

# ── Ansible ───────────────────────────────────────────────────────────────────

ansible-install-inlet: ## Install Ansible + collections for the inlet playbook
	pip install ansible
	ansible-galaxy collection install ansible.posix

ansible-install-k3s: ## Install Ansible + roles + collections for the k3s playbook
	pip install ansible
	ansible-galaxy role install -r ansible/requirements.yml
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
		EXTRA_VARS="-e qbittorrent_torrent_tailscale_ip=$${QBITTORRENT_TAILSCALE_IP}"; \
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

# ── K3s deployment test ───────────────────────────────────────────────────────

k3s-prepare: ## Patch targetRevision to COMMIT_SHA and validate kustomizations
	@echo "==> Patching targetRevision to $(COMMIT_SHA)"
	@find argocd/applications -name "application.yaml" -type f | while read -r f; do \
		if grep -q "github.com/St0rmingBr4in/home-kube-flux-config" "$$f"; then \
			echo "  $$f"; \
			sed -i.bak "s|targetRevision: HEAD|targetRevision: $(COMMIT_SHA)|g" "$$f"; \
			rm -f "$$f.bak"; \
		fi; \
	done
	$(MAKE) kustomize-validate

k3s-wait-ready: ## Wait for K3s node and CoreDNS to be ready
	kubectl wait --for=condition=Ready nodes --all --timeout=300s
	@echo "Waiting for CoreDNS pods to appear..."
	timeout 120 sh -c 'until kubectl get pods -n kube-system -l k8s-app=kube-dns -o name 2>/dev/null | grep -q pod; do sleep 2; done'
	kubectl wait --for=condition=Ready pod -l k8s-app=kube-dns -n kube-system --timeout=120s
	kubectl get nodes -o wide

k3s-install-argocd: ## Install ArgoCD into the K3s cluster
	kubectl create namespace argocd
	kubectl apply --server-side -n argocd \
		-f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
	kubectl wait --for=condition=available --timeout=600s deployment/argocd-server -n argocd
	kubectl wait --for=condition=available --timeout=600s deployment/argocd-repo-server -n argocd
	kubectl wait --for=condition=available --timeout=600s deployment/argocd-applicationset-controller -n argocd

k3s-configure-argocd: ## Download ArgoCD CLI and log in to the local cluster
	bash scripts/k3s-configure-argocd.sh

k3s-apply-apps: ## Apply ArgoCD ApplicationSets and verify apps are registered
	kubectl apply -k argocd/applications/
	kubectl get applications -n argocd

k3s-validate-apps: ## Wait for non-excluded apps to become Synced+Healthy
	bash scripts/k3s-validate-apps.sh

k3s-summary: ## Dump cluster debug info (runs even on failure)
	bash scripts/k3s-summary.sh
