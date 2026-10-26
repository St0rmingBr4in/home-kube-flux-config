# The one cause-based exception: a full disk breaks apps with no warning (Jellyfin won't boot
# under 2 GiB free), so alert while there is still room to act.
resource "datadog_monitor" "host_root_disk_full" {
  name  = "Root disk over 90% on {{host.name}}"
  type  = "query alert"
  query = "avg(last_15m):max:system.disk.in_use{device:/dev/sda1 OR device:/dev/mapper/pve-root} by {host,device} > 0.9"

  message = <<-EOT
    {{device.name}} on {{host.name}} is {{value}} full: kubelet starts evicting pods soon after.
    ${local.notify}
  EOT

  monitor_thresholds {
    critical = 0.9
  }

  tags = ["service:homelab", "managed-by:terraform"]
}

resource "datadog_monitor" "pvc_full" {
  name  = "Volume {{kube_namespace.name}}/{{persistentvolumeclaim.name}} over 90% full"
  type  = "query alert"
  query = "avg(last_15m):max:kubernetes.kubelet.volume.stats.used_bytes{*} by {kube_namespace,persistentvolumeclaim} / max:kubernetes.kubelet.volume.stats.capacity_bytes{*} by {kube_namespace,persistentvolumeclaim} > 0.9"

  message = <<-EOT
    Volume {{kube_namespace.name}}/{{persistentvolumeclaim.name}} is {{value}} full. Expand the PVC
    (synology-csi allows volume expansion) or clean up; media-library/media-downloads are the NAS share.
    ${local.notify}
  EOT

  monitor_thresholds {
    critical = 0.9
  }

  tags = ["service:homelab", "managed-by:terraform"]
}
