# Code Health Agents

This directory contains Claude Code agent configurations for automated infrastructure health maintenance. Each file defines a specialized agent that analyzes the codebase and creates GitHub issues.

## Agents

| File | Role | What it does |
|------|------|--------------|
| `cleanup.md` | Repo Janitor | Finds stale manifests, orphaned resources, debug scaffolding, and other clutter. Creates GitHub issues for cleanup tasks. |
| `single-source-of-truth.md` | Single Source of Truth Enforcer | Finds duplicated values: NFS paths, Tailscale IPs, provider versions, hostnames repeated across YAML/HCL/Makefile. Creates GitHub issues ranked by drift risk. |
| `fail-loud.md` | Fail-Loud Auditor | Finds K8s containers without resource limits/probes, Terraform resources missing required safety fields, and Ansible tasks that swallow errors. Creates GitHub issues ranked by severity. |
| `yagni-simplifier.md` | Simplicity Enforcer | Finds over-engineered ArgoCD ApplicationSets, unnecessary Kustomize layers, copy-pasted Terraform modules, and excess indirection. Creates GitHub issues ranked by simplicity gain. |
| `terraform-strictness.md` | Terraform Strictness Enforcer | Finds Terraform anti-patterns: hardcoded values that should be variables, missing variable descriptions/types, outputs without descriptions, and providers pinned loosely. Creates GitHub issues ranked by effort. |
| `infra-hygiene.md` | Infrastructure Hygiene Enforcer | Finds K8s resources missing standard labels, missing network policies, services without selector alignment, PVs/PVCs without proper storage class. Creates GitHub issues. |
| `swarm-fix.md` | Code Health Fixer | Picks the top 1-3 open code-health issues and implements fixes end-to-end, one commit per issue. |

## Usage

These agents are invoked via Claude Code. Each agent reads from the codebase and interacts with GitHub issues using the `gh` CLI.

The typical workflow is:

1. Run an analysis agent to create issues
2. Run the fixer agent (`swarm-fix.md`) to implement the highest-ROI fixes

All created issues use the `code-health` label for tracking.
