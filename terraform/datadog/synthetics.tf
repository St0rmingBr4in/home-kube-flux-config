# API synthetic tests for all homelab applications.
# Each test is tagged argocd_app:<name> so PostSync hooks can discover them by app.
#
# Kept in the UI on purpose: gxv-8ut-xdz "Jellyfin play movie" (browser test recorded in Datadog, holds
# a secure password Terraform can't read back, so an import would wipe it on the next apply).

locals {
  # Expected final HTTP status code after redirect resolution. All proxy-protected
  # apps return 200 because follow_redirects=true resolves the Authentik redirect inline.
  synthetic_expected_status = "200"

  # Maximum acceptable response time in milliseconds. The Authentik redirect chain through
  # inlet/Tailscale regularly takes 5-6 s, so 5000 ms flapped on argocd and bazarr.
  synthetic_response_time_ms = 10000

  # How often each synthetic test runs (seconds). 300 s = 5 minutes, the
  # minimum interval on the Datadog free/pro tier for API tests.
  synthetic_tick_every = 300

  # Probe locations for all synthetic tests. eu-west-1 is geographically
  # closest to the homelab; extend to a second location if false-positive
  # alerts from PoP outages become an issue.
  synthetic_locations = ["aws:eu-west-1"]

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
  message = "${each.value.url} is down or slower than ${local.synthetic_response_time_ms} ms. ${local.notify}"
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
    target   = local.synthetic_expected_status
  }

  assertion {
    type     = "responseTime"
    operator = "lessThan"
    target   = tostring(local.synthetic_response_time_ms)
  }

  options_list {
    tick_every       = local.synthetic_tick_every
    follow_redirects = true
  }

  locations = local.synthetic_locations

  tags = [
    "argocd_app:${each.key}",
    "env:prod",
    "managed-by:terraform",
  ]
}
