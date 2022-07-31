resource "google_compute_instance" "private-vm" {
    name = "private-vm"
    machine_type = "f1-micro"
    zone = "${var.region}-a"
    tags = ["ssh"]//adding this tag to assign the ssh firewall to this instances only 
    boot_disk {
        initialize_params {
            image = "debian-cloud/debian-9"
        }
    }
    network_interface {
        subnetwork  = google_compute_subnetwork.management_subnet.self_link
        network_ip = "10.0.1.2"
    }
    service_account {
    email  = google_service_account.k8s-service-account.email
    scopes = ["cloud-platform"]
    }
    metadata_startup_script = file("./install_kubectl.sh")
}