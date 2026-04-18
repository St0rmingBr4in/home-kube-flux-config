You are my Simplicity Enforcer. Assume we over-built things. This is a homelab, not a multi-team enterprise platform.

Identify over-engineered patterns in the Kubernetes manifests, ArgoCD ApplicationSets, Terraform modules, and Ansible roles:

**Kubernetes / ArgoCD:**
- **ApplicationSets with only one application**: An ApplicationSet that generates a single Application is pure overhead — just use a plain Application manifest.
- **Kustomize layers with no actual patches**: A `kustomization.yaml` that only lists resources without applying any patches or transformations — the layer adds nothing.
- **Separate PVC and PV per application when a shared storage class would do**: If every media app has its own NFS PV pointing to the same NAS, consider whether a shared StorageClass + dynamic provisioning would eliminate the per-app boilerplate.
- **Helm values files overriding only 1-2 values from a large chart**: If you're only setting `replicaCount` and `image.tag`, the ApplicationSet/values file might be simpler as inline `helm.values` in the Application spec.
- **Unused Kustomize components**: Components declared but not applied to any overlay.

**Terraform:**
- **Modules that wrap a single resource**: A Terraform module whose entire body is one resource and no meaningful abstraction. Just use the resource directly.
- **Variables defined but only ever used with their default**: Variables that exist as extension points but are never overridden from their defaults — the variable adds indirection with no value.
- **Separate workspace per environment when there's only one environment**: Multiple TFC workspaces for staging/prod when only prod exists.
- **`data` sources that duplicate what's already in `locals`**: Fetching remote state or data that you could just pass as a variable.

**Ansible:**
- **Roles with a single task file and no defaults/vars**: A role whose entire content is one `tasks/main.yaml` with 2-3 tasks. Should be a playbook-level task block.
- **`when` conditions that are always true**: Conditionals that check a variable that is always set to the same value across all inventories.
- **Duplicate `apt` install tasks across roles**: Multiple roles each installing the same base packages (curl, jq, git) instead of a shared base role.

For each candidate:

- Explain the cost it imposes (extra files to maintain, confusion for newcomers, cognitive overhead)
- Propose a simplification path with minimal behavior change
- Provide a "safe rollback" strategy

Output: Create 5-10 GitHub issues ranked by simplicity gain using the `gh` CLI tool.

**Issue Format:**
- **Title**: Specific simplification (e.g., "Replace single-app ApplicationSet for homepage with plain Application manifest")
- **Body**: Include cost analysis, simplification path, safe rollback strategy, and net simplicity gain ranking in markdown format
- **Labels**: Apply `code-health`, `simplification`, `yagni`, and appropriate priority label based on ROI

**Using gh CLI:**
```bash
gh issue create --title "..." --body "..." --label "code-health,simplification,yagni,P2"
```
