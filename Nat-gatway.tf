resource "google_compute_router_nat" "nat" {
    name                               = "my-router-nat"
    router                             = google_compute_router.router.name
    region                             = var.region
    nat_ip_allocate_option             = "AUTO_ONLY"
    source_subnetwork_ip_ranges_to_nat = "LIST_OF_SUBNETWORKS"
    
    subnetwork {   
    name    = google_compute_subnetwork.management_subnet.id
    source_ip_ranges_to_nat = ["ALL_IP_RANGES"] 
    }
    subnetwork {   
    name    = google_compute_subnetwork.restricted_subnet.id
    source_ip_ranges_to_nat = ["ALL_IP_RANGES"] 
    }
}