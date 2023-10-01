# argocd-workshop
Experimenting with ArgoCD

## TOC
- [About](#about)
- [Prerequisites](#prerequisites)
  - [Docker](#docker)
  - [Kubectl](#kubectl)
  - [Helm](#helm)
  - [Kind](#kind)
  - [ArgoCD CLI](#argocd-cli)
- [Kubernetes Cluster](#kubernetes-cluster)
- [ArgoCD Setup](#argocd-setup)
  - [Installation](#installation)
  - [Access ArgoCD UI](#access-argocd-ui)
  - [Authenticate ArgoCD CLI](#authenticate-argocd-cli)
- [ArgoCD Usage](#argocd-usage)
  - [ArgoCD CLI](#argocd-cli-1)
  - [ArgoCD UI](#argocd-ui)
- [Sealed Secrets](#sealed-secrets-and-storing-them-in-git)
  - [Installation](#sealed-secret-operator)
  - [kubeseal CLI](#kubeseal-cli)
## About

This is a workshop for demonstration of GitOps. I will be deploying ArgoCD on Kubernetes using KinD.

From [their documentation](https://argo-cd.readthedocs.io/en/stable/):

> Argo CD is a declarative, GitOps continuous delivery tool for Kubernetes.

## Prerequisites

If you are following along, you will need the following:

- [KinD](https://kind.sigs.k8s.io/docs/user/quick-start/#installation) and [Docker](https://docs.docker.com/get-docker/)
- [Helm](https://helm.sh/docs/intro/install/) and [Kubectl](https://kubernetes.io/docs/tasks/tools/)
- [ArgoCD CLI](https://argo-cd.readthedocs.io/en/stable/cli_installation/)

If you don't have them installed, don't worry as we will be installing them from scratch. I will be using Linux as my operating system, if you are using something else, you can follow the links provided above.

### Docker

If you can run `docker ps` you have docker installed already. I am using this on Linux to install Docker, if you are using a different operating system you can view their [installation documentation](https://docs.docker.com/engine/install/ubuntu/)

<details>
  <summary>Installation Steps</summary>

```bash
sudo apt update
sudo apt install ca-certificates curl gnupg lsb-release -y
sudo mkdir -m 0755 -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" \
| sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt update
sudo apt install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin -y
sudo usermod -aG docker $(whoami)
source ~/.bashrc
```

</details>

### Kubectl

If you need to install kubectl on a operating system other than Linux, have a look at their [installation documentation](https://kubernetes.io/docs/tasks/tools/)


<details>
  <summary>Installation Steps (latest)</summary>

```bash
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
rm -rf kubectl
```

</details>

### Helm

If you need to install kubectl on a operating system other than Linux, have a look at their [installation documentation](https://helm.sh/docs/intro/install/)

<details>
  <summary>Installation Steps</summary>

```bash
curl -LO https://get.helm.sh/helm-v3.11.2-linux-amd64.tar.gz
tar -xf helm-v3.11.2-linux-amd64.tar.gz
sudo install -o root -g root -m 0755 linux-amd64/helm /usr/local/bin/helm
rm -rf helm-v3.11.2-linux-amd64.tar.gz linux-amd64
```

</details>

### Kind

If you need to install kind on a operating system other than Linux, have a look at their [installation documentation](https://kind.sigs.k8s.io/docs/user/quick-start/#installation)

<details>
  <summary>Installation Steps</summary>

```bash
curl -Lo kind https://kind.sigs.k8s.io/dl/v0.17.0/kind-linux-amd64
sudo install -o root -g root -m 0755 kind /usr/local/bin/kind
rm -rf kind
```

</details>

### ArgoCD CLI

If you need to install argocd-cli on a operating system other than Linux, have a look at their [installation documentation](https://argo-cd.readthedocs.io/en/stable/cli_installation/)

<details>
  <summary>Installation Steps</summary>

```bash
curl -sSL -o argocd-linux-amd64 https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
sudo install -o root -g root -m 0755 argocd-linux-amd64 /usr/local/bin/argocd
rm argocd-linux-amd64
```

</details>

### Kubeseal CLI

During workshop we will use kubeseal cli in order to encrypt generic kubernetes secrets

<details>
  <summary>Installation Steps</summary>

```bash
KUBESEAL_VERSION='0.23.0'
wget "https://github.com/bitnami-labs/sealed-secrets/releases/download/v${KUBESEAL_VERSION:?}/kubeseal-${KUBESEAL_VERSION:?}-linux-amd64.tar.gz"
tar -xvzf kubeseal-${KUBESEAL_VERSION:?}-linux-amd64.tar.gz kubeseal
sudo install -m 755 kubeseal /usr/local/bin/kubeseal
```

</details>
## Kubernetes Cluster

Deploy a kubernetes cluster with [kind](https://kind.sigs.k8s.io/docs/user/quick-start/) and a list of images can be found on [github](https://github.com/kubernetes-sigs/kind/releases):

```bash
kind create cluster --config=kind/kind-config.yaml --image=kindest/node:v1.27.3
```

You should be able to interact with your cluster using:

```bash
kubectl get nodes
# NAME                   STATUS   ROLES           AGE   
# argocd-control-plane   Ready    control-plane   45s   
```

## ArgoCD Setup

### Installation

We will be installing ArgoCD with vanilla manifest, if you are looking for alternative methods we will heve helm option, look at their [installation documentation](https://argo-cd.readthedocs.io/en/stable/operator-manual/installation/).

```bash
# Create Argocd NS
kubectl create namespace argocd
kubectl apply -n argocd -f \
https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
# or in ha
kubectl apply -n argocd -f \
https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/ha/install.yaml
```

```bash
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update
helm install argocd argo/argo-cd --version 5.27.1 --namespace kube-system --set "configs.params.server\.insecure=true"
```

### Access ArgoCD UI

Once the installation process has been completed, you should be able to get the initial admin password from this secret:

```bash
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
```

Once you have copied the password, create a port forward to access the argocd ui:

```bash
kubectl -n argocd port-forward svc/argocd-server 8080:80
```

### Authenticate ArgoCD CLI

Ensure that you have a port-forward open to the server:

```bash
kubectl -n kube-system port-forward svc/argocd-server 8080:80
```

### Exracting  password
```bash
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d && echo
```

Use the argocd cli to logon to the server:

```bash
argocd login --insecure localhost:8080
# WARNING: server is not configured with TLS. Proceed (y/n)? y
# Username: admin
# Password:
# 'admin:login' logged in successfully
# Context 'localhost:8080' updated
```

Then authenticate again to your server:

```bash
argocd login --insecure localhost:8080
```

## ArgoCD Usage

This section will demonstrate how to create an application on ArgoCD which will reference and monitor our github repository for content and any changes that is being made.


### ArgoCD CLI

First create the application and connect the github repository  

```bash
#Deploying application
kubectl create ns guestbook-demo
argocd app create 00-tools --repo https://github.com/galphaa/workshop-gitops.git \
--path 00_argocd/00_tools --dest-server https://kubernetes.default.svc --dest-namespace default

argocd app create 01-guestbook --repo https://github.com/galphaa/workshop-gitops.git \
--path 00_argocd/01_guestbook --dest-server https://kubernetes.default.svc --dest-namespace guestbook-demo

kubectl port-forward  -n guestbook-demo svc/guestbook-ui 9090:80

#check status
argocd app get 01-guestbook
```

If we look at our resources using kubectl:

```bash
kubectl get all -A
```

Let's delete our application from the CLI, first list our applications

```bash
argocd app list --output name
```

Then delete the application:

```bash
argocd app delete 01-guestbook
# Are you sure you want to delete '01-guestbook' and all its resources? [y/n] y
# application '01-guestbook' deleted
```

## Sealed secrets controller and storing them in git

Before we start encrypting we need to install our sealed secret controller

```bash
https://github.com/bitnami-labs/sealed-secrets/releases/download/v${KUBESEAL_VERSION:?}/controller.yaml
```

Creating some demo secret from base64 and encrypring them via sealed controller

```bash
#Creating basic secret
cat <<EOL > secret.yaml
apiVersion: v1
data:
  secret: UzNDUjNUCg==
kind: Secret
metadata:
  creationTimestamp: null
  name: mysecret
  namespace: demo-app
EOL
```

###Sealing secret
kubeseal --format yaml <secret.yaml >sealedsecret.yaml

###Adding app
argocd app create 02-secret --repo https://github.com/galphaa/testerday2023.git \
--path 00_argocd/02_secret --dest-server https://kubernetes.default.svc --dest-namespace demo-app

kubectl logs -n demo-app demo-app


