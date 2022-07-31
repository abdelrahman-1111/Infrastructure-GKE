data "google_compute_disk" "jenkins-disk" {
    name    = "jenkins-disk"
    project = var.project
}