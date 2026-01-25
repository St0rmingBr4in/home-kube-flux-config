# Authentik Configuration

This directory contains the Authentik identity provider configuration for the cluster.

## Components

- **applicationset.yaml**: ArgoCD ApplicationSet for deploying Authentik
- **authentik-values.yaml**: Helm values for Authentik server, worker, PostgreSQL, and Redis
- **blueprint-argocd.yaml**: Blueprint ConfigMap that automatically creates:
  - ArgoCD Proxy Provider (forward auth mode)
  - ArgoCD Application
  - Outpost assignment (see Known Limitations below)
- **kustomization.yaml**: Kustomize resources including PV, PVC, secrets, and blueprints
- **postgres-pv.yaml** / **postgres-pvc.yaml**: PostgreSQL persistent storage
- **secret-vault.yaml**: Vault secret reference for credentials

## Blueprints

Blueprints are YAML files that declaratively configure Authentik resources. They are automatically discovered and applied when mounted to `/blueprints/custom/` in the server and worker pods.

### ArgoCD Blueprint

The `blueprint-argocd.yaml` creates:
- **Proxy Provider**: Forward auth for `argocd.st0rmingbr4in.com`
- **Application**: ArgoCD app with launch URL and icon
- **Outpost Assignment**: **(See Known Limitations)**

## Known Limitations

### Manual Outpost Assignment Required

⚠️ **Manual Step Required**: After the blueprint creates the ArgoCD provider, you must manually assign it to the embedded outpost:

1. Log into Authentik admin UI
2. Navigate to **Applications → Outposts**
3. Edit **"authentik Embedded Outpost"**
4. Add **"ArgoCD Provider"** to the providers list
5. Click **Update**

**Why?** Authentik blueprints currently don't support updating many-to-many relationships like outpost providers. This is tracked in:
- GitHub Issue: https://github.com/goauthentik/authentik/issues/6779
- Status: Open (as of 2025-01-25)

**Alternative Solutions:**
- Use the [Authentik Terraform Provider](https://registry.terraform.io/providers/goauthentik/authentik/latest/docs) for full IaC coverage
- Create a dedicated outpost via blueprint instead of updating the existing one

## Adding New Applications

To add a new application protected by Authentik:

1. **Create a Blueprint ConfigMap** (similar to `blueprint-argocd.yaml`):
   ```yaml
   - model: authentik_providers_proxy.proxyprovider
     attrs:
       name: MyApp Provider
       mode: forward_single
       external_host: https://myapp.example.com

   - model: authentik_core.application
     attrs:
       name: MyApp
       slug: myapp
       provider: !KeyOf myapp-provider
   ```

2. **Create IngressRoute** with Authentik middleware:
   ```yaml
   - kind: Rule
     match: Host(`myapp.example.com`)
     middlewares:
       - name: authentik-forward-auth
         namespace: prod-infra
     services:
       - name: myapp
         port: 8080
   ```

3. **Manually assign provider to outpost** (see Known Limitations above)

## References

- [Authentik Blueprints Documentation](https://docs.goauthentik.io/customize/blueprints)
- [Authentik Outposts Documentation](https://docs.goauthentik.io/add-secure-apps/outposts/)
- [Blueprint File Structure](https://docs.goauthentik.io/customize/blueprints/v1/structure/)
