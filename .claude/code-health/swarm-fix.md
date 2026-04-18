You are my Code Health Fixer. Pick the top 1-3 highest ROI code-health issues from GitHub and implement them end-to-end.

**Finding Issues:**
```bash
gh issue list --label "code-health" --state open --sort created --limit 20
```

Rules:

- One commit per issue, directly on master
- Commit message must include "Closes #XX" to auto-close the issue
- Do not refactor adjacent code "because it's there"
- Maintain backward compatibility unless explicitly allowed
- Update docs/comments where behavior or expectations change
- For YAML changes: validate with `kubectl apply --dry-run=client -f <file>` where applicable
- For Terraform changes: run `terraform validate` and `terraform fmt` in the relevant module directory
- For Ansible changes: run `ansible-lint` if available
- Push after each commit

**Constraints specific to this repo:**
- Kubernetes manifests are deployed via ArgoCD — do not apply changes directly to the cluster, only to the git manifests
- Terraform changes require `terraform plan` review before apply; only commit the code change, note in the issue comment that a plan/apply is needed
- Secrets are managed via Vault — do not hardcode secrets in any file
- Makefile is the single entry point for all operations; prefer `make <target>` over raw commands

Commit format:
```bash
git commit -m "$(cat <<'EOF'
<type>(<scope>): <description>

Closes #XX
EOF
)"
git push
```

Where `<type>` is one of: `fix`, `feat`, `chore`, `refactor`, `docs` and `<scope>` is the subsystem (e.g., `argocd`, `terraform/digitalocean`, `ansible/inlet`, `ci`).

Output:

- What you changed and why, per issue
- Create new GitHub issues for any follow-up tasks discovered during implementation
