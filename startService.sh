#!/bin/bash

checkRepo() {
  local ADD_REPO=$(helm repo list | grep $1 || true)
  echo "$ADD_REPO" 
}

checkInstall() {
  local INSTALLED=$(helm list --short -n $NAMESPACE | grep $1 || true)
  echo "$INSTALLED"
}

command_exists() {
  command -v "$1" >/dev/null 2>&1
}

set -e

# CONFIGURACIÓN
NAMESPACE=jenkins

# Check docker
if ! command_exists docker; then
  echo "Docker is not istalled. Please install Docker and try again."
  exit 1
fi

# Check kubectl
if ! command_exists kubectl; then
  echo "🔧 Installing kubectl..."
  curl -LO "https://dl.k8s.io/release/$(curl -sL https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
  sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
  rm kubectl
else
  echo "✅ kubectl is already installed."
fi

# Check minikube
if ! command_exists minikube; then
  echo "🔧 Installing minikube..."
  curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
  sudo install minikube-linux-amd64 /usr/local/bin/minikube
  rm minikube-linux-amd64
else
  echo "✅ minikube is already installed."
fi

# Check helm
if ! command_exists helm; then
  echo "🔧 Installing helm..."
  curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
else
  echo "✅ helm is already installed."
fi

echo "🚀 Starting Minikube..."
minikube start

echo "Creating namespace '$NAMESPACE'..."
kubectl create namespace $NAMESPACE > /dev/null 2>&1 || echo "Namespace '$NAMESPACE' already exists."

ADD_REPO=$(checkRepo jenkins)
if [[ -z "$ADD_REPO" ]]; then
  echo "Adding Jenkins repository..."
  helm repo add jenkins https://charts.jenkins.io
  helm repo update
else
  echo "Jenkins repository already added."
fi

ADD_REPO=$(checkRepo localstack)
if [[ -z "$ADD_REPO" ]]; then
  echo "Adding LocalStack repository..."
  helm repo add localstack https://localstack.github.io/helm-charts
  helm repo update
else
  echo "LocalStack repository already added."
fi

ADD_INSTALLED=$(checkInstall jenkins)
if [[ -z "$ADD_INSTALLED" ]]; then
  echo "Installing Jenkins in namespace '$NAMESPACE'..."
  helm install jenkins jenkins/jenkins -f jenkins.yaml --namespace $NAMESPACE
else
  echo "Jenkins is already installed in namespace '$NAMESPACE'."
fi

ADD_INSTALLED=$(checkInstall localstack)
if [[ -z "$ADD_INSTALLED" ]]; then
  echo "Installing LocalStack in namespace '$NAMESPACE'..."
  helm install localstack localstack/localstack -f localstack.yaml --namespace $NAMESPACE
else
  echo "LocalStack is already installed in namespace '$NAMESPACE'."
fi

echo "⏳ Waiting for pods to be ready..."

# Wait for all pods to be Running
while true; do
  NOT_READY=$(kubectl get pods -n $NAMESPACE --no-headers | grep -v '2/2' | grep -v '1/1' || true)
  if [[ -z "$NOT_READY" ]]; then
    echo "✅ All pods are ready."
    break
  fi
  echo "⏳ Waiting 5s more..."
  sleep 5
done

kubectl --namespace $NAMESPACE port-forward svc/jenkins 8080:8080 > /dev/null 2>&1 & echo $! > jenkins_port_forward.pid
kubectl --namespace $NAMESPACE port-forward svc/localstack 4566:4566 > /dev/null 2>&1 & echo $! > localstack_port_forward.pid