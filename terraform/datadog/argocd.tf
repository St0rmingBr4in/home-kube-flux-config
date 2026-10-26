# Alerts when an Argo CD app stays OutOfSync or not Healthy, e.g. a sync that keeps failing on
# an immutable field, or an app stuck deleting. Metric: Datadog's argocd check on the
# application controller (pod annotations in argocd/applications/core/argocd/argocd-values.yaml).
resource "datadog_monitor" "argocd_app_not_synced_or_healthy" {
  name = "Argo CD app {{name.name}} not Synced/Healthy for 30 minutes"
  type = "query alert"

  # app.info only reports an app's current sync/health pair, so a bad series exists only while
  # the app is in that state: a full window means 30 minutes in a row, and missing data resolves.
  query = "min(last_30m):sum:argocd.app_controller.app.info{NOT sync_status:synced OR NOT health_status:healthy} by {name} > 0"

  message = <<-EOT
    Argo CD app {{name.name}} has not been Synced and Healthy for 30 minutes.
    Check https://argocd.st0rmingbr4in.com/applications/argocd/{{name.name}} for the failing resource.
  EOT

  monitor_thresholds {
    critical = 0
  }

  require_full_window = true
  on_missing_data     = "resolve"

  tags = ["service:argocd", "managed-by:terraform"]
}

# The monitor above sees only bad series, so it reads "all fine" when the metric stops. This
# one alerts when the controller or the check stops reporting apps at all.
resource "datadog_monitor" "argocd_app_metrics_missing" {
  name  = "Argo CD app metrics missing"
  type  = "query alert"
  query = "min(last_30m):sum:argocd.app_controller.app.info{*} < 1"

  message = <<-EOT
    Datadog has received no argocd.app_controller.app.info for 30 minutes: the Argo CD application
    controller or Datadog's argocd check (its pod annotations) stopped, so app sync/health alerts are blind.
  EOT

  monitor_thresholds {
    critical = 1
  }

  notify_no_data    = true
  no_data_timeframe = 30

  tags = ["service:argocd", "managed-by:terraform"]
}
