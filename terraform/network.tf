resource "google_compute_network" "my_vpc" {
    name                    = "my-vpc"
    auto_create_subnetworks = "false"
    routing_mode = "REGIONAL"
}
resource "google_compute_subnetwork" "management_subnet" {
    name          = "management-subnetwork"
    ip_cidr_range = "10.0.1.0/24"
    region        = var.region
    network       = google_compute_network.my_vpc.id
    private_ip_google_access = true
}
resource "google_compute_subnetwork" "restricted_subnet" {
    name          = "restricted-subnetwork"
    ip_cidr_range = "10.0.2.0/24"
    region        = var.region
    network       = google_compute_network.my_vpc.id
    private_ip_google_access = true
    secondary_ip_range {
    range_name    = "pods"
    ip_cidr_range = "192.168.1.0/24"
    }
    secondary_ip_range {
    range_name    = "nodes"
    ip_cidr_range = "192.168.2.0/24"
    }
}