resource "google_service_account" "k8s-service-account" {
    account_id   = "k8s-service-account"
}

resource "google_project_iam_member" "k8s-iam-member" {
    project = "abdo-project-12345-354211"
    role    = "roles/container.admin"
    member  = "serviceAccount:${google_service_account.k8s-service-account.email}"
}
resource "google_service_account" "k8s-cluster" {
    account_id   = "k8s-cluster"
}

resource "google_project_iam_member" "cluster-iam-member" {
    project = "abdo-project-12345-354211"
    role    = "roles/storage.objectViewer"
    member  = "serviceAccount:${google_service_account.k8s-cluster.email}"
}
