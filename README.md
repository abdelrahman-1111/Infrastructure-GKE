# ITI graduation project
## brief about the project 
My goal was create a CI/CD pipelnie using jenkins to pull a repo and build the code then deploy it on pod, Jenkins runs on GKE provisioned by terraform, Both jenkins and the app are on the same cluster but in 2 diffrenet namespaces.

## provisioning the infrastructue 
- I started with setting GCP as my provider
- Got my credential to access the Cloud Platform with Google user credentials using command 

```gcloud auth login```

![image](https://user-images.githubusercontent.com/104630009/182127940-c20b89b9-82b4-46bb-a8dd-c1fba6046ea5.png)
- And upload my statefile on a bucket to be synchronized with the others 

![image](https://user-images.githubusercontent.com/104630009/180807017-00afc25c-7cf6-43c5-b11b-3ba0c0587783.png)
### Network
- I created a VPC with routing mode ragional as all my infrastructure will impelmented in the same region

![image](https://user-images.githubusercontent.com/104630009/180845657-eb89a9e0-ff54-4591-b254-ddd03fe13874.png)

- Subnet with CIDR range [10.0.1.24/24] in my VPC and name it management subnet 

![image](https://user-images.githubusercontent.com/104630009/180845957-9777b197-391a-4a3d-b391-b6feeca8e5d2.png)

- Subnet with CIDR range [10.0.2.24/24] in my VPC and name it restricted subnet with two secondry ip ranges for the cluster pods and cluster services 

![image](https://user-images.githubusercontent.com/104630009/180846280-564d5931-97d3-4078-bd01-897be67d6785.png)

- Then created the firewalll to accept only ssh connection on port 22 with a target to tag to assign it to my private subnet only and not the cluster

![image](https://user-images.githubusercontent.com/104630009/180830714-b23d4918-386e-49a7-a211-a0b8a9d51276.png)
- Then the router to assign it to the Nat gatway for the vpc

![image](https://user-images.githubusercontent.com/104630009/180831091-c9a8f5c0-5bea-4e8e-bf3b-30c84f5b4df6.png)
- And the Nat gatway to allow only managment subnet including my private instance to get its packages and updates 

![image](https://user-images.githubusercontent.com/104630009/180831599-2ae8749b-6e34-4263-af88-f1b90aa882b6.png)
### Service accounts
### I created a two service account one for my instance and one for the GKE cluster as the following
- The one attached to my instance have Role of container admin to have permissions to access my cluster 
![image](https://user-images.githubusercontent.com/104630009/180832720-8ecdd7b6-5c5f-4f8a-9245-19d44504be80.png)
- The one for my cluster have the Role of storage viwer to have permission to pull the images from my GCR repo
![image](https://user-images.githubusercontent.com/104630009/180833016-c90b6847-b723-4767-ada3-bc0d38650d27.png)
## Computing instance and GKE
### private VM
- Creating an instance in my managment subnet having tag [ssh] to allow the traffic on port 22 using my firewall and assign the service account to access the GKE and assign a strtup script to install gcloud and kubectl whicl i will discuss below 
![image](https://user-images.githubusercontent.com/104630009/180833348-48cce134-38c4-46c5-ad1d-29cb11657215.png)
### GKE 
- I created the GKE with in same region zone 'a' using variable 'region' in my VPC and defining the default created node pool to false to create my own pool but but the intial node count by 1 to create the master node in it 
![image](https://user-images.githubusercontent.com/104630009/180889728-1a055340-b996-4aaa-9b19-154dcb9dc134.png)
- ip allocation policy is where i define my pods and services IPs ranges are and this is what i have defined eariler in my restricted subnet as secondry IPs ranges
![image](https://user-images.githubusercontent.com/104630009/180890608-f4f817ea-65bb-4d8f-a31a-0649321f077e.png)
- configuring the private endpoints and nodes as true as make my cluster private and have no access from outside the subnet and assigning the master_ipv4_cidr_block with range of IPs does not overlap any IPs range of the cluster network to assign a private IP to ILB and my master node to be able to communicate with the worker nodes 
![image](https://user-images.githubusercontent.com/104630009/180891272-9a0916ef-34b1-495b-b9a9-ce85eb94270d.png)
- configure a master authorized network which is my managment subnet CIDR range to open the communication between the private VM and the master node to control the cluster from it 
![image](https://user-images.githubusercontent.com/104630009/180891330-9fb59138-7b88-4544-b430-bab4c6d5bb02.png)
- creating my worker node pool with name node pool in the same zone where is my cluster and assign the service account which allow give permission Role storage.Voewer to allow the nodes to pull images on GCR or Artifact repos and setting the scoop to be on all  platform
![image](https://user-images.githubusercontent.com/104630009/180891644-114dec81-1af3-4151-9f60-4392233a7ed0.png)
## provision the infrastructure
- Now i can provision this infrastructure using terraform command `terraform apply`
![image](https://user-images.githubusercontent.com/104630009/180893072-e79b58cf-5b5e-415c-8dbe-1a01f7c03d50.png)
## setting up the VM 
### startup script 
- I script the following bash script to add gcloud repo then install the gcloud and intiate it and add the kubectl repo and update the packages then install it 
![image](https://user-images.githubusercontent.com/104630009/180892634-2c54d4ea-6cb1-4729-8021-f636e5bc7423.png)
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
- To make sure that all my configurations and plugins are not gonna reset each time the pod is destroied i needed to mount a volume on jenkins home directory, ao i created a storage class 
of type gce/pd to auto create Persistent disks on GCP 
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
```gcloud compute scp --recurse ~/Infrastructure/jenkins  private-vm:~/yamls --project "hamada-1234"
```
![Screenshot from 2022-07-31 19-15-42](https://user-images.githubusercontent.com/104630009/182135525-cbfe8385-4b88-4226-ab84-d08f9177e045.png)

- Now deploy them using 
`kubectl apply -Rf yamls`
- And now jenkins is setup and running 
![Screenshot from 2022-08-01 00-58-37](https://user-images.githubusercontent.com/104630009/182136457-cc9098cc-f50a-46f1-b3e7-278e82fab5cf.png)
