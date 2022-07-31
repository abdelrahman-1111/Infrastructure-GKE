terraform {
    backend "gcs" {
    bucket  = "terraform-tfstate-file-gcp"
    }
}