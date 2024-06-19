terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "5.32.0"
    }

    google-beta = {
      source  = "hashicorp/google-beta"
      version = "5.32.0"
    }
  }
}

variable "project_id" {
  type        = string
  description = "Your GCP project ID."
}

variable "region" {
  type        = string
  description = "Your GCP region, like: us-central1"
}

variable "zone" {
  type        = string
  description = "Your GCP zone, like: us-central1-a"
}

variable "mongouri" {
  type        = string
  description = "Your MongoDB Connection URI"
}

# Configure the Google Cloud Provider
provider "google" {
  credentials = file("service-account.json")
  project = var.project_id
  region  = var.region
}

# Enable required APIs
resource "google_project_service" "filestore_api" {
  project = "appsmith-demos"
  service = "file.googleapis.com"
}

resource "google_project_service" "vpc_access_api" {
  project = "appsmith-demos"
  service = "vpcaccess.googleapis.com"
}

# Define the Filestore Instance
resource "google_filestore_instance" "appsmith_data" {
  name      = "appsmith-data"
  location  = var.zone
  tier      = "BASIC_HDD"
  networks {
    network = "default"
    modes   = ["MODE_IPV4"]
  }

  file_shares {
    name        = "share1"
    capacity_gb = 1024
  }
}

# Define the Serverless VPC Access Connector
resource "google_vpc_access_connector" "appsmith_connector" {
  name          = "appsmith-vpc-connector"
  region        = var.region 
  network       = "default"
  ip_cidr_range = "10.8.0.0/28"
}

# Define the Cloud Run Service for appsmith
resource "google_cloud_run_v2_service" "default" {
  project = var.project_id
  provider = google-beta
  name     = "cloudrun-service"
  location = var.region
  depends_on = [
    google_vpc_access_connector.appsmith_connector,
    google_filestore_instance.appsmith_data
  ]
  ingress = "INGRESS_TRAFFIC_ALL"
  
  template {
    execution_environment = "EXECUTION_ENVIRONMENT_GEN2"

    containers {
      image = "docker.io/appsmith/appsmith-ee"
      ports {
        container_port = 8080
      }
      resources {
        limits = {
          cpu    = 2
          memory = "4Gi"
        }
      }

      startup_probe {
        timeout_seconds = 300
      }

      # Add environment variables
      env {
        name  = "FILESTORE_IP_ADDRESS"
        value = google_filestore_instance.appsmith_data.networks[0].ip_addresses[0]
      }
      env {
        name  = "FILE_SHARE_NAME"
        value = google_filestore_instance.appsmith_data.file_shares[0].name
      }
      env {
        name  = "APPSMITH_MONGODB_URI"
        value = var.mongouri
      }
      env {
        name  = "APPSMITH_ENCRYPTION_SALT"
        value = "=DbdMPIu86Kc5ldd6RX5qyQ=="
      }
      env {
        name  = "APPSMITH_ENCRYPTION_PASSWORD"
        value = "=DbdMPIu86Kc5ldd6RX5qyQ=="
      }
      env {
        name  = "APPSMITH_ENABLE_EMBEDDED_DB"
        value = "0"
      }
      env {
        name  = "APPSMITH_DISABLE_EMBEDDED_KEYCLOAK"
        value = "1"
      }
    }

    scaling {
      min_instance_count = 1
      max_instance_count = 4
    }

    vpc_access{
      connector = google_vpc_access_connector.appsmith_connector.id
      egress = "ALL_TRAFFIC"
    }
  }
}
