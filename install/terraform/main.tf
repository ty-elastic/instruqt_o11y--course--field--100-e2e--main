locals {
  # String interpolation combining both variables
  cluster_name = "${var.cluster_name}-${var.labels.project}"
}

# Windows username: "win" prefix + 8 lowercase letters (max 20 chars, no special chars)
resource "random_string" "windows_username" {
  length  = 8
  upper   = false
  numeric = false
  special = false
}

# Windows password: 24 alphanumeric chars, meets complexity (upper + lower + numeric = 3 categories)
resource "random_password" "windows_password" {
  length      = 24
  upper       = true
  lower       = true
  numeric     = true
  special     = false
  min_upper   = 4
  min_lower   = 4
  min_numeric = 4
}

resource "google_compute_network" "main" {
  name                    = local.cluster_name
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "main" {
  name          = local.cluster_name
  ip_cidr_range = "10.0.0.0/24"
  region        = var.region
  network       = google_compute_network.main.id

  secondary_ip_range {
    range_name    = "pods"
    ip_cidr_range = "10.1.0.0/16"
  }

  secondary_ip_range {
    range_name    = "services"
    ip_cidr_range = "10.2.0.0/20"
  }
}

# Allow all internal traffic within the subnet (required for GKE node communication)
resource "google_compute_firewall" "allow_internal" {
  name    = "${local.cluster_name}-allow-internal"
  network = google_compute_network.main.self_link

  allow { protocol = "tcp" }
  allow { protocol = "udp" }
  allow { protocol = "icmp" }

  source_ranges = [
    google_compute_subnetwork.main.ip_cidr_range,
    google_compute_subnetwork.main.secondary_ip_range[0].ip_cidr_range,
  ]
}

# RDP reachable only from within the shared VPC subnet
resource "google_compute_firewall" "rdp_internal" {
  name    = "${local.cluster_name}-rdp-internal"
  network = google_compute_network.main.self_link

  allow {
    protocol = "tcp"
    ports    = ["3389"]
  }

  target_tags   = ["windows-rdp"]
  source_ranges = [google_compute_subnetwork.main.ip_cidr_range]
}

# Allow the Windows VM to make outbound connections to any host
resource "google_compute_firewall" "windows_egress" {
  name      = "${local.cluster_name}-windows-egress"
  network   = google_compute_network.main.self_link
  direction = "EGRESS"

  allow {
    protocol = "all"
  }

  target_tags        = ["windows-rdp"]
  destination_ranges = ["0.0.0.0/0"]
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
  network         = google_compute_network.main.self_link
  subnetwork      = google_compute_subnetwork.main.self_link

  ip_allocation_policy {
    cluster_secondary_range_name  = "pods"
    services_secondary_range_name = "services"
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
          env {
            name  = "WINDOWS_HOST_IP"
            value = google_compute_instance.windows_server.network_interface[0].network_ip
          }
          env {
            name  = "WINDOWS_HOST_USERNAME"
            value = "win${random_string.windows_username.result}"
          }
          env {
            name  = "WINDOWS_HOST_PASSWORD"
            value = random_password.windows_password.result
          }
        }
      }
    }
  }

  wait_for_completion = true

  timeouts {
    create = var.job_timeout
  }

  depends_on = [
    google_container_node_pool.primary_nodes,
    google_compute_instance.windows_server,
  ]
}

locals {
  windows_startup_auth = <<-EOT
      $username = "win${random_string.windows_username.result}"
      $password = '${random_password.windows_password.result}'
      $securePassword = ConvertTo-SecureString $password -AsPlainText -Force
      if (-not (Get-LocalUser -Name $username -ErrorAction SilentlyContinue)) {
        New-LocalUser -Name $username -Password $securePassword -PasswordNeverExpires
        Add-LocalGroupMember -Group "Administrators" -Member $username
      }

      Add-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0
      Start-Service sshd
      Set-Service -Name sshd -StartupType 'Automatic'
    EOT
}

resource "google_compute_instance" "windows_server" {
  name         = "${local.cluster_name}-windows"
  machine_type = "n1-standard-4"
  zone         = var.zone

  tags = ["windows-rdp"]

  boot_disk {
    initialize_params {
      image = "windows-cloud/windows-2022"
      size  = 100
      type  = "pd-balanced"
    }
  }

  network_interface {
    network    = google_compute_network.main.self_link
    subnetwork = google_compute_subnetwork.main.self_link
  }

  metadata = {
    windows-startup-script-ps1 = local.windows_startup_auth
  }

  labels = var.labels
}
