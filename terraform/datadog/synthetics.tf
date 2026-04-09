# API synthetic tests for all homelab applications.
# Each test is tagged argocd_app:<name> so PostSync hooks can discover them by app.
#
# Import existing tests:
#   terraform import 'datadog_synthetics_test.apps["sonarr"]'      ech-uc2-d4x
#   terraform import 'datadog_synthetics_test.apps["qbittorrent"]' zg8-czm-guh
#
# Unmanaged browser tests (too complex to codify):
#   9ib-2m2-u44  Jellyfin invalid login
#   gxv-8ut-xdz  Jellyfin play movie
#   23n-tay-497  Home
#
# Deleted (paused, no longer needed):
#   s6c-n6n-5d6  Test on palworld.st0rmingbr4in.com
#   vxe-m89-trv  qbittorrent auth (browser)

locals {
  synthetics = {
    argocd = {
      name = "API check on argocd.st0rmingbr4in.com"
      url  = "https://argocd.st0rmingbr4in.com/"
    }
    authentik = {
      name = "API check on authentik.st0rmingbr4in.com"
      url  = "https://authentik.st0rmingbr4in.com/"
    }
    bazarr = {
      name = "API check on bazarr.st0rmingbr4in.com"
      url  = "https://bazarr.st0rmingbr4in.com/"
    }
    cleanuparr = {
      name = "API check on cleanuparr.st0rmingbr4in.com"
      url  = "https://cleanuparr.st0rmingbr4in.com/"
    }
    homepage = {
      name = "API check on home.st0rmingbr4in.com"
      url  = "https://home.st0rmingbr4in.com/"
    }
    jellyfin = {
      name = "API check on jellyfin.st0rmingbr4in.com"
      url  = "https://jellyfin.st0rmingbr4in.com/"
    }
    jellyseerr = {
      name = "API check on jellyseerr.st0rmingbr4in.com"
      url  = "https://jellyseerr.st0rmingbr4in.com/"
    }
    prowlarr = {
      name = "API check on prowlarr.st0rmingbr4in.com"
      url  = "https://prowlarr.st0rmingbr4in.com/"
    }
    qbittorrent = {
      name = "API check on qbittorrent.st0rmingbr4in.com"
      url  = "https://qbittorrent.st0rmingbr4in.com/"
    }
    radarr = {
      name = "API check on radarr.st0rmingbr4in.com"
      url  = "https://radarr.st0rmingbr4in.com/"
    }
    sonarr = {
      name = "API check on sonarr.st0rmingbr4in.com"
      url  = "https://sonarr.st0rmingbr4in.com/"
    }
  }
}

resource "datadog_synthetics_test" "apps" {
  for_each = local.synthetics

  name    = each.value.name
  type    = "api"
  subtype = "http"
  status  = "live"

  request_definition {
    method = "GET"
    url    = each.value.url
  }

  assertion {
    type     = "statusCode"
    operator = "is"
    target   = "200"
  }

  assertion {
    type     = "responseTime"
    operator = "lessThan"
    target   = "5000"
  }

  options_list {
    tick_every = 300 # 5 minutes
  }

  locations = ["aws:eu-west-1"]

  tags = [
    "argocd_app:${each.key}",
    "env:prod",
    "managed-by:terraform",
  ]
}
