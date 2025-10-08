
Launch an Instance of Ubuntu,t2 large, 30 GB in AWS
No, we are using the public IP of the instance and keyname to log in to the instance using MobaXterm agent
Now update the server using  
~~~
sudo apt update -y
~~~
Now install  git and dev tools, Node.js and npm, Docker on the server
~~~
sudo apt -y install git curl build-essential ca-certificates
# Download and install nvm:
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh | bash

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"

# instead of restarting the shell
\. "$HOME/.nvm/nvm.sh"

# Download and install Node.js:
nvm install 22 -y

node -v 
npm -v
~~~
~~~
#Docker Installation
# Add Docker's official GPG key:
sudo apt-get update
sudo apt-get install ca-certificates curl
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

# Add the repository to Apt sources:
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update -y
sudo apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin -y
~~~

Now, make a new project folder (keeps things tidy)

~~~
cd $HOME
mkdir -p nextjs-project
cd nextjs-project
pwd
~~~

We will create a project folder named nextjs-app so the scaffold doesn’t accidentally reuse the name app and cause nested folders.
~~~
npx create-next-app@latest nextjs-app --typescript --app --use-npm --yes
~~~

Inspect the new project structure
~~~
cd nextjs-app

# or simple listing:
ls -la
ls -la app
~~~

Run the development server (make it accessible externally)
~~~
# from inside nextjs-project/nextjs-app
npm run dev -- -H 0.0.0.0 -p 3000
~~~

Now in your local browser open:
http://<EC2_PUBLIC_IP>:3000

<img width="1015" height="653" alt="chrome_hTk00MNPZc" src="https://github.com/user-attachments/assets/86f2800c-ba86-4436-88d7-fe99ef7f5cde" />


Now Create a Dockerfile in the app directory
Ensure you are in the project root:
~~~
cd ~/nextjs-project/nextjs-app
pwd
# should show: /home/ubuntu/nextjs-project/nextjs-app
~~~

vi Dockerfile
# Stage 1: builder (install all deps & build)
FROM node:20-alpine AS builder
WORKDIR /app

# Copy package files and install dependencies (dev + prod)
COPY package*.json ./
RUN npm ci --legacy-peer-deps

# Copy everything and build
COPY . .
RUN npx next build

# Stage 2: runtime (smaller, uses built output & node_modules from builder)
FROM node:20-alpine AS runner
WORKDIR /app
ENV NODE_ENV=production

# Copy package.json (useful for metadata) and node_modules from builder
COPY --from=builder /app/package.json ./
COPY --from=builder /app/node_modules ./node_modules

# Copy Next.js build output and app/public folders
COPY --from=builder /app/.next .next
COPY --from=builder /app/app ./app
COPY --from=builder /app/public ./public
COPY --from=builder /app/next.config.ts ./

EXPOSE 3000
# Start the Next.js production server
CMD ["npx", "next", "start", "-p", "3000"]

~~~
docker build -t nextjs-demo:final .
docker run -dt --name nextjs-cont -p 3000:3000 nextjs-demo:final
docker images    #list the images
docker ps -a         #list the containers
~~~

Now again, check in the browser using
http://<EC2_PUBLIC_IP>:3000

<img width="1015" height="653" alt="chrome_hTk00MNPZc" src="https://github.com/user-attachments/assets/da1ebdec-30cd-4198-ad3b-babadf908e02" />


Now go to GitHub and create a new repository 
Clone the repo link into the EC2 and push all the files into the repo using
~~~
git add .
git commit -m "Initial: Next.js app + Dockerfile" 
git branch -M main
git remote add origin git@github.com:pj013525/next.js-assignment.git
git push -u origin main
~~~
Now refresh the GitHub repo page, and you will see the files pushed from the local repo to the remote repository 
========================================================================================================================================================================================================

Create & run GitHub Actions workflow to build & push Docker image to GHCR

Where to run: your EC2 shell, inside your repo root: ~/nextjs-project/nextjs-app
~~~
cd ~/nextjs-project/nextjs-app
pwd
# expected output: /home/ubuntu/nextjs-project/nextjs-app
~~~

Create the workflows directory and write the YAML:
~~~
mkdir -p .github/workflows

#vi .github/workflows/ci-ghcr.yml
name: Build & Push Docker image to GHCR

on:
  push:
    branches: [ "main" ]

permissions:
  contents: read
  packages: write
  id-token: write

jobs:
  build-and-push:
    runs-on: ubuntu-latest

    steps:
      - name: Checkout repository
        uses: actions/checkout@v4

      - name: Set up QEMU
        uses: docker/setup-qemu-action@v3

      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v3

      - name: Log in to GitHub Container Registry (GHCR)
        uses: docker/login-action@v3
        with:
          registry: ghcr.io
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}

      - name: Build and push Docker image
        uses: docker/build-push-action@v4
        with:
          context: .
          file: ./Dockerfile
          push: true
          tags: |
            ghcr.io/${{ github.repository_owner }}/${{ github.repository }}:latest
            ghcr.io/${{ github.repository_owner }}/${{ github.repository }}:${{ github.sha }}
          cache-from: type=gha
          cache-to: type=gha,mode=max
~~~
		  
Commit & Push workflow update

In your EC2 terminal:
~~~
git add .github/workflows/docker-build.yml
git commit -m "fix: lowercase GHCR image name"
git push		  
~~~	  

Once you push, go to GitHub → Actions tab → you’ll see a new workflow run automatically.
It should now build and push successfully to GHCR.

After success, check here:

https://github.com/pj013525?tab=packages
You’ll see your image under Packages → nextjs-assignment

<img width="1340" height="678" alt="sB5GgF0Wsd" src="https://github.com/user-attachments/assets/e7a550ea-4d0f-499c-bb6a-6fdb6c52d9c0" />


Now create a Kubernetes Manifest files for deployment and service to deploy the application

In the EC2 terminal create a directory and write the deployment.yml and service.yml files in that directory
~~~
mkdir -p k8s
cd k8s
~~~
echo *************************************** | docker login ghcr.io -u pj013525 --password-stdin

kubectl create secret docker-registry ghcr-secret \
  --docker-server=ghcr.io \
  --docker-username=pj013525 \
  --docker-password=ghp_Lfl0BRR8LOs60sVvZu69ctF5Wu********* \
  --docker-email=pj*********gmail.com

vi deployment.yaml
~~~
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nextjs-deployment
  labels:
    app: nextjs
spec:
  replicas: 2
  selector:
    matchLabels:
      app: nextjs
  template:
    metadata:
      labels:
        app: nextjs
    spec:
      containers:
        - name: nextjs-container
          image: ghcr.io/pj013525/nextjs-assignment:latest
          imagePullPolicy: IfNotPresent
          ports:
            - containerPort: 3000
          readinessProbe:
            httpGet:
              path: /
              port: 3000
            initialDelaySeconds: 5
            periodSeconds: 10
          livenessProbe:
            httpGet:
              path: /
              port: 3000
            initialDelaySeconds: 10
            periodSeconds: 15
      imagePullSecrets:
        - name: ghcr-secret
~~~

replicas: 2 → two pods for high availability
readinessProbe → ensures pod is ready before traffic is sent
livenessProbe → restarts pod if it becomes unhealthy
image → your GHCR Docker image


vi service.yaml
~~~
apiVersion: v1
kind: Service
metadata:
  name: nextjs-service
spec:
  type: NodePort
  selector:
    app: nextjs
  ports:
    - protocol: TCP
      port: 3000
      targetPort: 3000
      nodePort: 30000
~~~

type: NodePort → allows accessing the app via EC2 public IP + nodePort
port: 3000 → internal cluster port
nodePort: 30000 → exposed port on your EC2 host	

Now install kubectl and minikube in your EC2 terminal
~~~
#Kubectl installation
curl -o kubectl https://amazon-eks.s3.us-west-2.amazonaws.com/1.19.6/2021-01-05/bin/linux/amd64/kubectl
chmod +x ./kubectl
sudo mv ./kubectl /usr/local/bin
kubectl version --short --client

#Minikube Installation
sudo apt install -y conntrack curl apt-transport-https
curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
sudo install minikube-linux-amd64 /usr/local/bin/minikube
minikube version
~~~

Start Minikube
~~~
minikube start --driver=docker
~~~

--driver=docker → uses Docker as the VM for pods

Minikube creates a single-node Kubernetes cluster inside Docker

Check status:
~~~
minikube status
~~~

You should see host, kubelet, apiserver, and kubeconfig all running.

Set kubectl context to Minikube
~~~
kubectl config use-context minikube
kubectl get nodes
~~~

Ensures kubectl commands affect your Minikube cluster

Should show 1 node ready

Push these deployment.yaml and service.yaml files to the GitHub repo using 
~~~
git add deployment.yaml service.yaml
git commit -m "deployment files"
git push origin main
~~~

Now Apply Kubernetes manifests
~~~
kubectl apply -f deployment.yaml
kubectl apply -f service.yaml
~~~

Check pods and service
~~~
kubectl get pods
kubectl get svc
~~~
<img width="771" height="377" alt="MobaXterm_dDgMVqPKHM" src="https://github.com/user-attachments/assets/c2f2f33f-c0d6-4c2f-9cdb-b6b6eb88f136" />

Then, you can access your app in the browser via:

http://<EC2-public-IP>:30000
<img width="996" height="670" alt="chrome_LdVEXOHq3p" src="https://github.com/user-attachments/assets/f35ca912-e94b-4f03-8568-d3fde03b2168" />


