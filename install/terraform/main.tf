locals {
  # String interpolation combining both variables
  cluster_name = "${var.cluster_name}-${var.labels.project}"
}

resource "google_container_cluster" "primary" {
  name     = local.cluster_name
  location = var.zone

  release_channel {
    channel = "REGULAR"
  }

  remove_default_node_pool = true
  initial_node_count       = 1
  deletion_protection      = false

  networking_mode = "VPC_NATIVE"
  network         = "projects/${var.project}/global/networks/${local.cluster_name}"
  subnetwork      = "projects/${var.project}/regions/${var.region}/subnetworks/${local.cluster_name}"

  # Constrain the pod/service ranges. A /20 (4096 pod IPs) is ample for a 
  # 1-node demo cluster.
  ip_allocation_policy {
    cluster_ipv4_cidr_block  = "/20"
    services_ipv4_cidr_block = "/24"
  }

  addons_config {
    horizontal_pod_autoscaling {
      disabled = false
    }
    http_load_balancing {
      disabled = false
    }
    gce_persistent_disk_csi_driver_config {
      enabled = true
    }
  }

  resource_labels = var.labels
}

resource "google_container_node_pool" "primary_nodes" {
  name       = "${local.cluster_name}-pool"
  cluster    = google_container_cluster.primary.id
  location   = var.zone
  node_count = var.node_count

  node_config {
    machine_type = var.machine_type
    image_type   = "COS_CONTAINERD"
    disk_type    = var.disk_type
    disk_size_gb = var.disk_size_gb

    metadata = {
      disable-legacy-endpoints = "true"
    }

    # advanced_machine_features {
    #   threads_per_core = 2
    #   enable_nested_virtualization = true
    # }

    shielded_instance_config {
      enable_secure_boot          = false
      enable_integrity_monitoring = true
    }

    labels = var.labels
  }

  management {
    auto_repair  = true
    auto_upgrade = true
  }

  upgrade_settings {
    max_surge       = 1
    max_unavailable = 0
  }
}

resource "kubernetes_service_account_v1" "install" {
  metadata {
    name      = "${var.job_name}-sa"
    namespace = var.job_namespace
  }
}

resource "kubernetes_cluster_role_binding_v1" "install" {
  metadata {
    name = "${var.job_name}-admin-binding"
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "cluster-admin" # Use a more restrictive role in production
  }

  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account_v1.install.metadata[0].name
    namespace = var.job_namespace
  }
}

resource "kubernetes_job_v1" "install" {
  metadata {
    name      = var.job_name
    namespace = var.job_namespace
  }

  spec {
    backoff_limit = var.job_backoff_limit

    template {
      metadata {
        labels = {
          app = var.job_name
        }
      }

      spec {
        restart_policy       = "Never"
        service_account_name = kubernetes_service_account_v1.install.metadata[0].name

        container {
          name  = "install"
          image = var.job_image

          env {
            name  = "ELASTICSEARCH_URL"
            value = var.elasticsearch_url
          }
          env {
            name  = "ELASTICSEARCH_APIKEY"
            value = var.elasticsearch_apikey
          }
          env {
            name  = "FLEET_URL"
            value = var.fleet_url
          }
          env {
            name  = "KIBANA_URL"
            value = var.kibana_url
          }
          env {
            name  = "INGEST_URL"
            value = var.ingest_url
          }
        }
      }
    }
  }

  wait_for_completion = true

  timeouts {
    create = var.job_timeout
  }

  depends_on = [google_container_node_pool.primary_nodes]
}
