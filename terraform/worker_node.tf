resource "google_container_node_pool" "worker_nodes" {
    name       = "workers"
    location = "${var.region}-a"
    cluster    = google_container_cluster.my-cluster.name
    node_count = 1

    max_pods_per_node = 20

    node_config {
    preemptible  = true
    machine_type = "n1-standard-1"
    # service_account = google_service_account.k8s-cluster.email
    
    oauth_scopes = [
        "https://www.googleapis.com/auth/cloud-platform"]
    }
}