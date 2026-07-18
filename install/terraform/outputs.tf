output "windows_host" {
  value = google_compute_instance.windows_server.network_interface[0].network_ip
}

output "windows_username" {
  value = random_string.windows_username.result
}

output "windows_password" {
  value     = random_password.windows_password.result
  sensitive = true
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
data "kubernetes_service_v1" "traefik_ext" {
  metadata {
    name      = "traefik"
    namespace = "traefik"
  }

  depends_on = [kubernetes_job_v1.install]
}

data "kubernetes_secret" "traefik" {
  metadata {
    name      = "traefik-auth"
    namespace = "traefik"
  }
}

output "traefik_auth" {
  value       = kubernetes_secret.traefik.data
  sensitive   = true
}

output "wiki_url" {
  value = "http://${data.kubernetes_service_v1.traefik_ext.status[0].load_balancer[0].ingress[0].ip}:9010"
}

output "trader_na_url" {
  value = "http://${data.kubernetes_service_v1.traefik_ext.status[0].load_balancer[0].ingress[0].ip}:9000"
}

output "trader_emea_url" {
  value = "http://${data.kubernetes_service_v1.traefik_ext.status[0].load_balancer[0].ingress[0].ip}:9001"
}

output "grafana_url" {
  value = "http://${data.kubernetes_service_v1.traefik_ext.status[0].load_balancer[0].ingress[0].ip}:9012"
}

output "ramen_url" {
  value = "http://${data.kubernetes_service_v1.traefik_ext.status[0].load_balancer[0].ingress[0].ip}:9011"
}

output "windows_url" {
  value = "http://${data.kubernetes_service_v1.traefik_ext.status[0].load_balancer[0].ingress[0].ip}:9013/guacamole"
}