resource "google_compute_router" "router" {
    name    = "my-router"
    region  = google_compute_subnetwork.management_subnet.region
    network = google_compute_network.my_vpc.id
}