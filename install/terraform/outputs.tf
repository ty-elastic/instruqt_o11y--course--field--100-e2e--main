output "windows_host" {
  value = google_compute_instance.windows_server.network_interface[0].network_ip
}

output "windows_username" {
  value = "win${random_string.windows_username.result}"
}

output "windows_password" {
  value     = random_password.windows_password.result
}

output "cluster_name" {
  value = google_container_cluster.primary.name
}

output "cluster_endpoint" {
  value     = google_container_cluster.primary.endpoint
  sensitive = true
}

output "get_credentials_command" {
  description = "Run this to point kubectl at the new cluster"
  value       = "gcloud container clusters get-credentials ${google_container_cluster.primary.name} --zone ${var.zone} --project ${var.project}"
}

output "job_name" {
  value = kubernetes_job_v1.install.metadata[0].name
}

# Services below are created by the install Job, so these data sources must
# not be read until the Job has finished running.
data "kubernetes_service_v1" "wiki_ext" {
  metadata {
    name      = "wiki-ext"
    namespace = "wiki"
  }

  depends_on = [kubernetes_job_v1.install]
}

data "kubernetes_service_v1" "trader_na_ext" {
  metadata {
    name      = "proxy-ext"
    namespace = "trading-na"
  }

  depends_on = [kubernetes_job_v1.install]
}

data "kubernetes_service_v1" "trader_emea_ext" {
  metadata {
    name      = "proxy-ext"
    namespace = "trading-emea"
  }

  depends_on = [kubernetes_job_v1.install]
}

data "kubernetes_service_v1" "grafana_ext" {
  metadata {
    name      = "grafana-ext"
    namespace = "infra"
  }

  depends_on = [kubernetes_job_v1.install]
}

data "kubernetes_service_v1" "ramen_ext" {
  metadata {
    name      = "ramen-ext"
    namespace = "default"
  }

  depends_on = [kubernetes_job_v1.install]
}

data "kubernetes_service_v1" "windows_ext" {
  metadata {
    name      = "windows-ext"
    namespace = "infra"
  }

  depends_on = [kubernetes_job_v1.install]
}

output "wiki_url" {
  value = "http://${data.kubernetes_service_v1.wiki_ext.status[0].load_balancer[0].ingress[0].ip}:${data.kubernetes_service_v1.wiki_ext.spec[0].port[0].port}"
}

output "trader_na_url" {
  value = "http://${data.kubernetes_service_v1.trader_na_ext.status[0].load_balancer[0].ingress[0].ip}:${data.kubernetes_service_v1.trader_na_ext.spec[0].port[0].port}"
}

output "trader_emea_url" {
  value = "http://${data.kubernetes_service_v1.trader_emea_ext.status[0].load_balancer[0].ingress[0].ip}:${data.kubernetes_service_v1.trader_emea_ext.spec[0].port[0].port}"
}

output "grafana_url" {
  value = "http://${data.kubernetes_service_v1.grafana_ext.status[0].load_balancer[0].ingress[0].ip}:${data.kubernetes_service_v1.grafana_ext.spec[0].port[0].port}"
}

output "ramen_url" {
  value = "http://${data.kubernetes_service_v1.ramen_ext.status[0].load_balancer[0].ingress[0].ip}:${data.kubernetes_service_v1.ramen_ext.spec[0].port[0].port}"
}

output "windows_url" {
  value = "http://${data.kubernetes_service_v1.windows_ext.status[0].load_balancer[0].ingress[0].ip}:${data.kubernetes_service_v1.windows_ext.spec[0].port[0].port}/guacamole"
}