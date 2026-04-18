locals {
  # Session cookie lifetime for proxy-protected apps. 24 h is the Authentik
  # upstream default; a short TTL limits exposure time for stolen session cookies.
  app_token_validity = "hours=24"

  apps = {
    argocd = {
      name        = "ArgoCD"
      slug        = "argo-cd"
      url         = "https://argocd.st0rmingbr4in.com"
      icon        = "https://raw.githubusercontent.com/walkxcode/dashboard-icons/main/png/argocd.png"
      description = "GitOps Continuous Delivery"
    }
    argo_workflows = {
      name        = "Argo Workflows"
      slug        = "argo-workflows"
      url         = "https://argo.st0rmingbr4in.com"
      icon        = "https://raw.githubusercontent.com/walkxcode/dashboard-icons/main/png/argo-workflows.png"
      description = "CI Workflow Engine"
    }
    bazarr = {
      name        = "Bazarr"
      slug        = "bazarr"
      url         = "https://bazarr.st0rmingbr4in.com"
      icon        = "https://raw.githubusercontent.com/walkxcode/dashboard-icons/main/png/bazarr.png"
      description = "Subtitles Manager"
    }
    cleanuparr = {
      name        = "Cleanuparr"
      slug        = "cleanuparr"
      url         = "https://cleanuparr.st0rmingbr4in.com"
      icon        = null
      description = "Automated Stalled Download Cleanup"
    }
    prowlarr = {
      name        = "Prowlarr"
      slug        = "prowlarr"
      url         = "https://prowlarr.st0rmingbr4in.com"
      icon        = "https://raw.githubusercontent.com/walkxcode/dashboard-icons/main/png/prowlarr.png"
      description = "Indexer Manager"
    }
    qbittorrent = {
      name        = "qBittorrent"
      slug        = "qbittorrent"
      url         = "https://qbittorrent.st0rmingbr4in.com"
      icon        = "https://raw.githubusercontent.com/walkxcode/dashboard-icons/main/png/qbittorrent.png"
      description = "Download Client"
    }
    radarr = {
      name        = "Radarr"
      slug        = "radarr"
      url         = "https://radarr.st0rmingbr4in.com"
      icon        = "https://raw.githubusercontent.com/walkxcode/dashboard-icons/main/png/radarr.png"
      description = "Movie Manager"
    }
    sonarr = {
      name        = "Sonarr"
      slug        = "sonarr"
      url         = "https://sonarr.st0rmingbr4in.com"
      icon        = "https://raw.githubusercontent.com/walkxcode/dashboard-icons/main/png/sonarr.png"
      description = "TV Show Manager"
    }
  }
}

resource "authentik_provider_proxy" "apps" {
  for_each = local.apps

  name               = "${each.value.name} Provider"
  authorization_flow = data.authentik_flow.default_authorization.id
  invalidation_flow  = data.authentik_flow.default_invalidation.id
  mode               = "forward_single"
  external_host      = each.value.url

  access_token_validity = local.app_token_validity

  # jwt_federation_* fields are auto-managed by Authentik — do not override.
  lifecycle {
    ignore_changes = [jwt_federation_providers, jwt_federation_sources]
  }
}

resource "authentik_application" "apps" {
  for_each = local.apps

  name               = each.value.name
  slug               = each.value.slug
  protocol_provider  = authentik_provider_proxy.apps[each.key].id
  meta_launch_url    = each.value.url
  meta_icon          = each.value.icon
  meta_description   = each.value.description
  policy_engine_mode = "any"
  open_in_new_tab    = true
}
