variable "datadog_api_key" {
  description = "Datadog API key"
  type        = string
  sensitive   = true
}

variable "datadog_app_key" {
  description = "Datadog Application key"
  type        = string
  sensitive   = true
}

variable "datadog_api_url" {
  description = "Datadog API endpoint URL (e.g. https://api.datadoghq.eu/ for EU region)"
  type        = string
  default     = "https://api.datadoghq.eu/"
}
