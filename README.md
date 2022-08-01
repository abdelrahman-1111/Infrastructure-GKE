# ITI graduation project

## Brief about the project 
My goal was create a CI/CD pipelnie using jenkins to pull a repo and build the code then deploy it on pod, Jenkins runs on GKE provisioned by terraform, Both jenkins and the app are on the same cluster but in 2 diffrenet namespaces.
## Infrastructure architecture
![GCP-infrastructure drawio (1)](https://user-images.githubusercontent.com/104630009/182145998-33493605-8a84-4a96-b1a3-a896c3d1ea57.png)

## provisioning the infrastructue 
- I started with setting GCP as my provider
- Got my credential to access the Cloud Platform with Google user credentials using command 

```gcloud auth login```

![image](https://user-images.githubusercontent.com/104630009/182127940-c20b89b9-82b4-46bb-a8dd-c1fba6046ea5.png)
- And upload my statefile on a bucket to be synchronized with the others 
```
terraform {
    backend "gcs" {
    bucket  = "terraform-tfstate-file-gcp"
    }
}
```
## Network
- I created a VPC with routing mode ragional as all my infrastructure will impelmented in the same region
```
resource "google_compute_network" "my_vpc" {
    name                    = "my-vpc"
    auto_create_subnetworks = "false"
    routing_mode = "REGIONAL"
}
```

- Subnet with CIDR range [10.0.1.24/24] in my VPC and name it management subnet 

```
resource "google_compute_subnetwork" "management_subnet" {
    name          = "management-subnetwork"
    ip_cidr_range = "10.0.1.0/24"
    region        = var.region
    network       = google_compute_network.my_vpc.id
    private_ip_google_access = true
}
````

- Subnet with CIDR range [10.0.2.24/24] in my VPC and name it restricted subnet with two secondry ip ranges for the cluster pods and cluster services 
```
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
```

- Then created the firewalll to accept only ssh connection on port 22 with a target to tag to assign it to my private instance
```
resource "google_compute_firewall" "allow-ssh" {
    name        = "ssh-firewall"
    network     = google_compute_network.my_vpc.name
    description = "Creates firewall rule allow to ssh from anywhere"
    source_ranges = ["0.0.0.0/0"]
    target_tags = ["ssh"]//adding target tags to specify this firewall to only instances have it
    allow {
    protocol  = "tcp"
    ports     = ["22"]
    }
}
```
- Then the router to assign it to the Nat gatway for the vpc
```
resource "google_compute_router" "router" {
    name    = "my-router"
    region  = var.region
    network = google_compute_network.my_vpc.id
    bgp {
    asn = 64514
    }
}
```
- And the Nat gatway to allow both management subnet and restricted subnet to get thier packages and updates 
```
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
```


## Service accounts
### I created a two service account one for my instance and one for the GKE cluster as the following
- The one attached to my instance have Role of container admin to have permissions to access my cluster 
```
resource "google_service_account" "k8s-service-account" {
    account_id   = "k8s-service-account"
}

resource "google_project_iam_member" "k8s-iam-member" {
    project = var.project
    role    = "roles/container.admin"
    member  = "serviceAccount:${google_service_account.k8s-service-account.email}"
}

```
- The one for my cluster have the Role of storage viwer to have permission to pull the images from my GCR repo
```
resource "google_service_account" "k8s-cluster" {
    account_id   = "k8s-cluster"
}

resource "google_project_iam_member" "cluster-iam-member" {
    project = var.project
    role    = "roles/storage.objectViewer"
    member  = "serviceAccount:${google_service_account.k8s-cluster.email}"
}

```
## Computing instance and GKE
### private VM
- Creating an instance in my managment subnet having tag [ssh] to allow the traffic on port 22 using my firewall and assign the service account to access the GKE and assign a strtup script to install gcloud and kubectl to control my GKE cluster  
```
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
```
### GKE 
- I created the GKE with in same region zone 'a' using variable 'region' in my VPC and defining the default created node pool to false to create my own pool.
```
resource "google_container_cluster" "my-cluster" {
    name     = "my-gke-cluster"
    location = "${var.region}-a"
    
    network = google_compute_network.my_vpc.name
    subnetwork = google_compute_subnetwork.restricted_subnet.name
    networking_mode = "VPC_NATIVE"
    
    remove_default_node_pool = true
    initial_node_count   = 1
    
```
- ip allocation policy is where i define my pods and services IPs ranges are and this is what i have defined eariler in my restricted subnet as secondry IPs ranges
```
    ip_allocation_policy {
        cluster_secondary_range_name = google_compute_subnetwork.restricted_subnet.secondary_ip_range.0.range_name
        services_secondary_range_name = google_compute_subnetwork.restricted_subnet.secondary_ip_range.1.range_name
    }
```
- configuring the private endpoints and nodes as true as make my cluster private and have no access from outside the subnet and assigning the master_ipv4_cidr_block with range of IPs does not overlap any IPs range of the cluster network to assign a private IP to ILB and my master node to be able to communicate with the worker nodes 
```
    #to disable any access to my cluster from outside my vpc 
    private_cluster_config {
    enable_private_endpoint = true
    enable_private_nodes = true
    master_ipv4_cidr_block = "10.1.0.0/28"
    }
```
- configure a master authorized network which is my managment subnet CIDR range to open the communication between the private VM and the master node to control the cluster from it 
```
    master_authorized_networks_config {
    cidr_blocks {
        cidr_block = google_compute_subnetwork.management_subnet.ip_cidr_range
        display_name = "auth_master"
        }
     }
```
### node pool
- creating my worker node pool with name node pool in the same zone where is my cluster and assign the service account which allow give permission Role storage.Voewer to allow the nodes to pull images on GCR or Artifact repos and setting the scoop to be on all  platform
```
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
```
## provision the infrastructure
- Now i can provision this infrastructure using terraform command `terraform apply`
![image](https://user-images.githubusercontent.com/104630009/180893072-e79b58cf-5b5e-415c-8dbe-1a01f7c03d50.png)
## setting up the VM 
### startup script 
- I script the following bash script to add gcloud repo then install the gcloud and intiate it and add the kubectl repo and update the packages then install it 
```
#!/bin/bash
#install gcloud
sudo apt-get install apt-transport-https ca-certificates gnupg
echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" | sudo tee -a /etc/apt/sources.list.d/google-cloud-sdk.list
curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key --keyring /usr/share/keyrings/cloud.google.gpg add -
sudo apt-get update && sudo apt-get install google-cloud-cli
sudo apt-get install google-cloud-sdk-gke-gcloud-auth-plugin
gcloud init

#Install kubectl
sudo apt-get update
sudo apt-get install -y apt-transport-https ca-certificates curl
sudo curl -fsSLo /usr/share/keyrings/kubernetes-archive-keyring.gpg https://packages.cloud.google.com/apt/doc/apt-key.gpg
echo "deb [signed-by=/usr/share/keyrings/kubernetes-archive-keyring.gpg] https://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee /etc/apt/sources.list.d/kubernetes.list
sudo apt-get update
sudo apt-get install -y kubectl
```
### ssh to the private VM 
- Now i need to ssh the private VM to setup my configuration to my cluster and copy the jenkins deployment and service yaml files to deploy and expose it
- So first i made sure that the user i use is authorized to access my project and resources 
![image](https://user-images.githubusercontent.com/104630009/180893970-a4460fc0-c801-4bd8-833a-392aacbe9907.png)
- next i ssh my private VM using the `gcloud compute ssh` command
![image](https://user-images.githubusercontent.com/104630009/180894134-f1dadba5-a8f6-48c4-a0eb-4b4d2f8b6d9f.png)
- after ensure that kubectl and gcloud is installed
![image](https://user-images.githubusercontent.com/104630009/180894344-71084e61-a0a4-41dd-a813-0d59a442bc1f.png)
![image](https://user-images.githubusercontent.com/104630009/180894409-20ff8256-dd4a-4573-b5fa-615a1f3f24c2.png)
- i configured my cluster using `gcloud container cluster get-credetintials` 
![image](https://user-images.githubusercontent.com/104630009/180894809-189a0a3c-742d-4221-a4ae-675c3bafc262.png)
- created two name spaces using command 
```
kubectl create ns dev
kubectl create ns prod
```
![Screenshot from 2022-07-31 17-00-26](https://user-images.githubusercontent.com/104630009/182129654-b76aca1f-69dc-48e3-8c78-978a4eb39780.png)

- Now i can write my deployment yaml file to deploy jenkins
```
apiVersion: apps/v1
kind: Deployment
metadata:
  name: jenkins
  namespace: dev
  labels: 
    app: jenkins
spec:
  replicas: 2
  selector: 
    matchLabels:
      app: jenkins
  template:
    metadata:
      labels:
        app: jenkins
    spec:
      containers:
      - name: jenkins
        image: abdelrahman1111/docker-jenkins:docker-jenkins-kubectl
        ports:
        - containerPort: 8080
        volumeMounts:
        - mountPath: /var/jenkins_home
          name: jenkins-volume
      volumes:
        - name: jenkins-volume
          persistentVolumeClaim:
            claimName:  pvc-jenkins 
```
            
- then the service yaml to expose it 

```
apiVersion: v1
kind: Service
metadata:
  name: jenkins-service
  namespace: dev
  annotations:
        cloud.google.com/load-balancer-type: "External"
spec:
  selector:
    app: jenkins
  type: LoadBalancer
  ports:
    - protocol: TCP
      port: 8080
      targetPort: 8080
```
- To make sure that all my configurations and plugins are not gonna reset each time the pod is destroied i needed to mount a volume on jenkins home directory, so i created a storage class of type gce/pd to auto create Persistent disks on GCP 
```
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: jenins-disk
provisioner: kubernetes.io/gce-pd
parameters:
  type: pd-standard
  fstype: ext4
  replication-type: none```
- but to link this volume to my jenkins deployment i needed to create PVC [Persistent Volume Claim] to attach the volume 
```apiVersion: v1
kind: PersistentVolumeClaim
metadata:
    name: pvc-jenkins
    namespace: dev
spec:
    storageClassName: "jenins-disk" 
    accessModes:
        - ReadWriteOnce
    resources:
        requests:
            storage: 10Gi
```
- Now i jest need to copy these file to my vm to apply it on my cluster, so i used gcloud secure copy command to copy them 
```gcloud compute scp --recurse ~/Infrastructure/jenkins  private-vm:~/yamls --project "hamada-1234"```
![Screenshot from 2022-07-31 19-15-42](https://user-images.githubusercontent.com/104630009/182135525-cbfe8385-4b88-4226-ab84-d08f9177e045.png)

- Now deploy them using 
`kubectl apply -Rf yamls`
- And now jenkins is setup and running 
![Screenshot from 2022-08-01 00-58-37](https://user-images.githubusercontent.com/104630009/182136457-cc9098cc-f50a-46f1-b3e7-278e82fab5cf.png)
## Create clusterRole for jenkins pod
- Now my jenkins is set up and able to execute the kubectl commands but it has no permissions on my cluster so, to grant it the needed permissions i created a custerRole to core API group like pods and app API group like deployment 
```
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: cluster-role
rules:
- apiGroups: [""]
  resources: ["*"]
  verbs: ["*"]
- apiGroups: ["apps"]
  resources: ["*"]
  verbs: ["*"]
  ```
  - i need to create a service account to be able to attach these permissions to my jenkins deployment(pods) 
``` 
apiVersion: v1
kind: ServiceAccount
metadata:
  name: cluster-admin
  namespace: dev
```
- and to link the clusterRole with this service account i must create clusterRleBinding
```
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: cluster-onwer
subjects:
- kind: ServiceAccount
  name: cluster-admin 
  namespace: dev 
roleRef:
  kind: ClusterRole
  name: cluster-role
  apiGroup: rbac.authorization.k8s.io
```
> Now my jenkins is ready and have the write permissions to create a deployment and a service account for my app, so lets move to the another part 

[The deplyment repo](https://github.com/abdelrahman-1111/deploy-app-GKE.git)
