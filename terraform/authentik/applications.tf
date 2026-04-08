locals {
  apps = {
    argocd = {
      name        = "ArgoCD"
      url         = "https://argocd.st0rmingbr4in.com"
      icon        = "https://raw.githubusercontent.com/walkxcode/dashboard-icons/main/png/argocd.png"
      description = "GitOps Continuous Delivery"
    }
    bazarr = {
      name        = "Bazarr"
      url         = "https://bazarr.st0rmingbr4in.com"
      icon        = "https://raw.githubusercontent.com/walkxcode/dashboard-icons/main/png/bazarr.png"
      description = "Subtitles Manager"
    }
    cleanuparr = {
      name        = "Cleanuparr"
      url         = "https://cleanuparr.st0rmingbr4in.com"
      icon        = null
      description = "Automated Stalled Download Cleanup"
    }
    prowlarr = {
      name        = "Prowlarr"
      url         = "https://prowlarr.st0rmingbr4in.com"
      icon        = "https://raw.githubusercontent.com/walkxcode/dashboard-icons/main/png/prowlarr.png"
      description = "Indexer Manager"
    }
    qbittorrent = {
      name        = "qBittorrent"
      url         = "https://qbittorrent.st0rmingbr4in.com"
      icon        = "https://raw.githubusercontent.com/walkxcode/dashboard-icons/main/png/qbittorrent.png"
      description = "Download Client"
    }
    radarr = {
      name        = "Radarr"
      url         = "https://radarr.st0rmingbr4in.com"
      icon        = "https://raw.githubusercontent.com/walkxcode/dashboard-icons/main/png/radarr.png"
      description = "Movie Manager"
    }
    sonarr = {
      name        = "Sonarr"
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
  mode               = "forward_single"
  external_host      = each.value.url
}

resource "authentik_application" "apps" {
  for_each = local.apps

  name               = each.value.name
  slug               = each.key
  protocol_provider  = authentik_provider_proxy.apps[each.key].id
  meta_launch_url    = each.value.url
  meta_icon          = each.value.icon
  meta_description   = each.value.description
  policy_engine_mode = "any"
  open_in_new_tab    = true
}
