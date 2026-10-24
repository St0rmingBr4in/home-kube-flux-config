---
name: bump-versions
description: >
  Upgrade or bump component versions in this homelab repo: Helm charts in ArgoCD
  ApplicationSets (traefik, cert-manager, authentik, argo-cd, datadog, vault, woodpecker,
  the media apps…), k3s, Terraform providers, CI and container images. Use when the user
  asks to update, upgrade, bump or "mettre à jour" a component or the whole cluster, to
  review or merge a Renovate PR, to pick a target version, to check whether a version is
  outdated, or to change the Renovate config. Also use before touching any chartVersion,
  k3s_release_version, Terraform required_providers version or image tag.
---

# Bumping versions in home-kube-flux-config

## Version policy

- **Majors and minors wait 30 days** after their release (`minimumReleaseAge: "30 days"`
  in `renovate.json`; the `renovate/stability-days` check enforces it). Never pick a
  major or minor younger than that, even by hand.
- **Patches ship at once**: always run the latest patch of the chosen minor.
- **Renovate owns every version.** Pin exact versions (no `latest`, no `>=` ranges) in a
  place a Renovate manager scans, so nothing is bumped by hand only.
- **Patches and minors automerge** once CI is green.
- **Majors are reviewed PRs**: read the release notes, check breaking changes, then merge
  by hand.
- **k3s: patches automerge, minors are reviewed.** A Kubernetes minor can remove APIs, and
  add-ons (Traefik, cert-manager, operators) declare which Kubernetes versions they support.
  Merging k3s minors by hand keeps the cluster around n-1.

Don't add `allowedVersions` pins to emulate "n-1 minor" for other components; the 30-day
wait plus reviewed majors is the rule.

## Where versions live

| Component | File | Field |
|-----------|------|-------|
| Helm charts | `argocd/applications/**/applicationset.yaml` | `chartVersion` |
| Chart values (image overrides) | `argocd/applications/**/*-values.yaml` | `image.tag` and similar |
| k3s | `ansible/inventory/group_vars/k3s_cluster/vars.yaml` | `k3s_release_version` |
| Terraform providers | `terraform/<module>/main.tf` + `.terraform.lock.hcl` | `required_providers` |
| Plain manifest images | `argocd/**/*.yaml` | `image:` |
| Ansible Galaxy roles and collections | `ansible/requirements.yml` | `version` |
| CI images | `.woodpecker/*.yaml` | `image:` |

Renovate manages all of these through `renovate.json` (custom regex managers for the
ApplicationSets and k3s). Prefer reviewing or rebasing the existing Renovate PR over
editing a version by hand.

## Procedure

1. **Find current and target.** Read the current version from the file above, and check
   what's actually deployed (`kubectl get pods -n <ns> -o jsonpath='{..image}'`, or
   `kubectl get nodes -o wide` for k3s). Inventory and cluster can drift: k3s has been
   behind its inventory before because the playbook couldn't run in CI.
2. **Read every release note between current and target.** Look for breaking changes,
   renamed or removed values keys, CRD changes, required migrations, minimum Kubernetes
   version, and whether skipping minors is allowed. For charts, also diff the chart's
   `values.yaml` between the two versions.
3. **Render before pushing.** Pull the target chart (`helm pull <chart> --repo <url>
   --version <v> --untar`) and run `helm template` with the repo's values file. A values
   key the new chart rejects fails the render (this kept Datadog from syncing for five
   months). For Terraform, run `terraform plan` and expect no unexpected diff.
4. **One component per commit.** Push to `master` (no PRs for manual bumps; see
   `CLAUDE.md`).
5. **Verify after each one.** ArgoCD app `Synced` and `Healthy`
   (`kubectl -n argocd get application <app>`), pods running with no restarts climbing,
   and the app's own health endpoint. Check `.status.conditions` for a `ComparisonError`:
   an app can stay "Healthy" on the old version while every new sync fails.
6. **Only then move to the next component.**

## Gotchas

- **Memory reservations.** `compliance/memory-webhook` sets request = limit when only one
  is given, and 512Mi when neither is. node1 runs close to fully reserved, so a rolling
  update that needs room for two pods can get stuck in `Pending`. Check
  `kubectl describe node` before upgrading something large; single-replica Deployments
  should use `maxSurge: 0, maxUnavailable: 1`.
- **Charts that stop at a minor.** Some charts (Authentik's) stop publishing patch
  releases for a minor once the next one is out. A temporary `image.tag` pin is fine,
  with a comment saying to drop it at the next minor upgrade.
- **Renovate PRs show stale failures** until Renovate rebases them. Re-run or rebase
  before concluding a bump is broken.
- **CI clones sometimes fail on DNS** (`Could not resolve host: github.com`). That's
  not the bump; re-run the pipeline.

## What to report

For each component: current → target version, breaking changes found (or "none"), what
was verified after the sync, and anything left for the user to decide (majors, k3s
minors).
