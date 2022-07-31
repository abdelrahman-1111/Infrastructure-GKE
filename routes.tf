resource "google_compute_router" "router" {
    name    = "my-router"
    region  = var.region
    network = google_compute_network.my_vpc.id
    bgp {
    asn = 64514
    }
}