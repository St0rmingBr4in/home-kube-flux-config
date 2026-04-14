# Homelab Flux Config — Developer Notes

## Adding a new Terraform module

All Terraform modules use HCP Terraform Cloud (TFC) as a state backend with
**local execution mode** — the plan/apply runs on the GitHub Actions runner (or
locally), state is stored in TFC.

**Problem**: when `terraform init` connects to a TFC workspace that does not
yet exist, TFC auto-creates it with `execution_mode = "remote"`. The CI
environment variables (e.g. `TF_VAR_*`) are then invisible to the remote
runner, causing authentication failures.

**Required process** — follow these steps in order:

### 1. Add the workspace to the TFE module

Edit `terraform/tfe/workspaces.tf` and add the new workspace to the `locals`
map:

```hcl
locals {
  workspaces = {
    # existing workspaces …
    homelab_mymodule = "homelab-mymodule"
  }
}
```

### 2. Apply the TFE module first

```bash
make terraform-tfe-apply
```

This pre-creates the workspace in TFC with `execution_mode = "local"` **before**
`terraform init` can auto-create it with the wrong default.

### 3. Create the new module

Create `terraform/mymodule/` following the standard layout:

| File | Purpose |
|------|---------|
| `main.tf` | `terraform { cloud { workspaces { name = "homelab-mymodule" } } }` + provider |
| `variables.tf` | Input variables (mark secrets `sensitive = true`) |
| `*.tf` | Resources |
| `.gitignore` | Copy from another module — excludes `.terraform/`, `*.tfvars` |

### 4. Initialise and generate the lock file

```bash
make terraform-mymodule-init
```

The lock file (`.terraform.lock.hcl`) must be committed.

### 5. Add Makefile targets

```makefile
TF_MYMODULE_DIR := terraform/mymodule

terraform-mymodule-init: ## Initialise MyModule Terraform
	terraform -chdir=$(TF_MYMODULE_DIR) init

terraform-mymodule-plan: ## Plan MyModule Terraform
	terraform -chdir=$(TF_MYMODULE_DIR) plan

terraform-mymodule-apply: ## Apply MyModule Terraform
	terraform -chdir=$(TF_MYMODULE_DIR) apply -auto-approve
```

Also add `$(TF_MYMODULE_DIR)` to the `terraform-fmt` loop and the `.PHONY`
list.

### 6. Add a CI workflow

Copy `.github/workflows/terraform-datadog.yml` as a template. Key points:

- Add `workflow_dispatch:` trigger so you can manually re-run without a push.
- Pass secrets as `TF_VAR_*` env vars on the Plan and Apply steps.
- Apply only on `push` to `master` (not on `pull_request` or
  `workflow_dispatch`).

### 7. Add secrets to GitHub

Any `sensitive` variables need a matching GitHub Actions secret
(`TF_VAR_my_secret` → secret name `MY_SECRET`, referenced as
`${{ secrets.MY_SECRET }}`).

---

## Re-provisioning the inlet VPS

inlet's Tailscale hostname is pinned to `inlet` via `--hostname=inlet` in
`ansible/inventory/group_vars/inlet.yaml`. Tailscale appends a `-N` suffix
(`inlet-1`, `inlet-2`) when a device with the same name already exists in the
tailnet. **Always follow this order to keep the name stable:**

### 1. Delete the old device from the Tailscale admin console

Before provisioning a new inlet droplet (or re-running `tailscale up` with a
new OAuth key):

1. Go to <https://login.tailscale.com/admin/machines>
2. Find the old `inlet` device (it will be offline)
3. Click `…` → **Delete**

Skipping this step causes the new device to register as `inlet-1`, which
breaks the `--exit-node=inlet` reference in qbittorrent's Tailscale addon.

### 2. Run Ansible

```bash
make ansible-inlet
```

The `tailscale up --hostname=inlet ...` task will now claim the `inlet` name
cleanly. No authkey is needed if the node is already running (re-auth case:
pass `-e tailscale_authkey=<oauth-secret>`).

### 3. Update qbittorrent exit node reference (if needed)

If the qbittorrent values still reference an IP address (`--exit-node=100.x.x.x`)
from a previous workaround, update it back to `--exit-node=inlet`:

```yaml
TS_EXTRA_ARGS: "--exit-node=inlet --exit-node-allow-lan-access"
```

### Why `-N` suffixes happen on other nodes (traefik-2, pihole-1, etc.)

The Tailscale Kubernetes operator assigns hostnames via the
`tailscale.com/hostname` annotation. Old StatefulSet pods leave stale Tailscale
devices behind when they are deleted. Remove stale devices from the admin
console whenever you see unexpected `-N` suffixes.
