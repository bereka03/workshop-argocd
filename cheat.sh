# Creating kind cluster with default values and networking
kind create cluster --config=kind/kind-config.yaml


#Install Argo CLI
# https://argo-cd.readthedocs.io/en/stable/cli_installation/#download-with-curl
curl -sSL -o argocd-linux-amd64 https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
sudo install -m 555 argocd-linux-amd64 /usr/local/bin/argocd
rm argocd-linux-amd64


# Create Argocd NS
kubectl create namespace argocd
kubectl apply -n argocd -f \
https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
# or in ha
kubectl apply -n argocd -f \
https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/ha/install.yaml


# Installing Argo CLI 
VERSION=$(curl --silent "https://api.github.com/repos/argoproj/argo-cd/releases/latest" | grep '"tag_name"' | sed -E 's/.*"([^"]+)".*/\1/')
curl -sSL -o /usr/local/bin/argocd https://github.com/argoproj/argo-cd/releases/download/$VERSION/argocd-linux-amd64
chmod +x /usr/local/bin/argocd
argocd version

#Connecting argo web ui
kubectl port-forward svc/argocd-server -n argocd 8080:80
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d && echo
argocd login localhost:8080
Username: admin
Password: ?????


#Deploying application 
kubectl create ns guestbook-demo
argocd app create 00-tools --repo https://github.com/galphaa/testerday2023.git \
--path 00_argocd/00_tools --dest-server https://kubernetes.default.svc --dest-namespace default

argocd app create 01-guestbook --repo https://github.com/galphaa/testerday2023.git \
--path 00_argocd/01_guestbook --dest-server https://kubernetes.default.svc --dest-namespace guestbook-demo

kubectl port-forward  -n guestbook-demo svc/guestbook-ui 9090:80

#check status
argocd app get 01-guestbook


# Installing kubeseal
# https://github.com/bitnami-labs/sealed-secrets#installation
# https://github.com/bitnami-labs/sealed-secrets/releases/
# Fetch the latest sealed-secrets version using GitHub API
KUBESEAL_VERSION=$(curl -s https://api.github.com/repos/bitnami-labs/sealed-secrets/tags | jq -r '.[0].name' | cut -c 2-)

# Check if the version was fetched successfully
if [ -z "$KUBESEAL_VERSION" ]; then
    echo "Failed to fetch the latest KUBESEAL_VERSION"
    exit 1
fi

wget "https://github.com/bitnami-labs/sealed-secrets/releases/download/v${KUBESEAL_VERSION}/kubeseal-${KUBESEAL_VERSION}-linux-amd64.tar.gz"
tar -xvzf kubeseal-${KUBESEAL_VERSION}-linux-amd64.tar.gz kubeseal
sudo install -m 755 kubeseal /usr/local/bin/kubeseal

#installing Controller
kubectl apply -f https://github.com/bitnami-labs/sealed-secrets/releases/download/$VERSION/controller.yaml

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

#Sealing secret 
kubeseal --format yaml <secret.yaml >sealedsecret.yaml

#Adding app 
argocd app create 02-secret --repo https://github.com/galphaa/testerday2023.git \
--path 00_argocd/02_secret --dest-server https://kubernetes.default.svc --dest-namespace demo-app

kubectl logs -n demo-app demo-app
