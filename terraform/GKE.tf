resource "google_container_cluster" "my-cluster" {
    name     = "my-gke-cluster"
    location = "${var.region}-a"
    
    network = google_compute_network.my_vpc.name
    subnetwork = google_compute_subnetwork.restricted_subnet.name
    networking_mode = "VPC_NATIVE"
    
    remove_default_node_pool = true
    initial_node_count   = 1
    
    ip_allocation_policy {
        cluster_secondary_range_name = google_compute_subnetwork.restricted_subnet.secondary_ip_range.0.range_name
        services_secondary_range_name = google_compute_subnetwork.restricted_subnet.secondary_ip_range.1.range_name
    }
    #to disable any access to my cluster from outside my vpc 
    private_cluster_config {
    enable_private_endpoint = true
    enable_private_nodes = true
    master_ipv4_cidr_block = "10.1.0.0/28"
    }

    master_authorized_networks_config {
    cidr_blocks {
        cidr_block = google_compute_subnetwork.management_subnet.ip_cidr_range
        display_name = "auth_master"
        }
    }

    network_policy {
        enabled = true
        }
}