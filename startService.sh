#!/bin/bash

checkRepo() {
  local ADD_REPO
  ADD_REPO=$(helm repo list | grep "$1" || true)
  echo "$ADD_REPO" 
}

checkInstall() {
  local INSTALLED
  INSTALLED=$(helm list --short -n "$2" | grep "$1" || true)
  echo "$INSTALLED"
}

command_exists() {
  command -v "$1" >/dev/null 2>&1
}

set -e

# ===============================
# CONFIGURATION
# ===============================
NS_JENKINS=jenkins
NS_MONITORING=monitoring
NS_SONAR=sonar

# ===============================
# CHECKS
# ===============================

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


# ===============================
# NAMESPACES
# ===============================

for ns in $NS_JENKINS $NS_MONITORING $NS_SONAR; do
  echo "⚙️ Creating namespace '$ns'..."
  kubectl create namespace "$ns" > /dev/null 2>&1 || echo "✅ Namespace '$ns' already exists."
done

# ===============================
# REPOSITORIES
# ===============================

declare -A repos=(
  [jenkins]="https://charts.jenkins.io"
  [localstack]="https://localstack.github.io/helm-charts"
  [sonarqube]="https://SonarSource.github.io/helm-chart-sonarqube"
  [prometheus-community]="https://prometheus-community.github.io/helm-charts"
  [grafana]="https://grafana.github.io/helm-charts"
)

for repo in "${!repos[@]}"; do
  if [[ -z $(checkRepo "$repo") ]]; then
    echo "⚙️ Adding $repo repository..."
    helm repo add "$repo" "${repos[$repo]}"
    echo "✅ $repo repository added."
  else
    echo "✅ $repo repository already added."
  fi
done

# ===============================
# CHARTS
# ===============================

if [[ -z $(checkInstall jenkins "$NS_JENKINS") ]]; then
  echo "🔧 Installing Jenkins in namespace '$NS_JENKINS'..."
  helm install jenkins jenkins/jenkins -f jenkins.yaml --namespace $NS_JENKINS
  echo "✅ Jenkins installed in namespace '$NS_JENKINS'."
else
  echo "✅ Jenkins is already installed in namespace '$NS_JENKINS'."
fi

if [[ -z $(checkInstall localstack "$NS_JENKINS") ]]; then
  echo "🔧 Installing LocalStack in namespace '$NS_JENKINS'..."
  helm install localstack localstack/localstack -f localstack.yaml --namespace $NS_JENKINS
  echo "✅ LocalStack installed in namespace '$NS_JENKINS'."
else
  echo "✅ LocalStack is already installed in namespace '$NS_JENKINS'."
fi

if [[ -z $(checkInstall sonarqube "$NS_SONAR") ]]; then
  echo "🔧 Installing SonarQube in namespace '$NS_SONAR'..."
  export MONITORING_PASSCODE="password"
  helm install sonarqube sonarqube/sonarqube --namespace $NS_SONAR --set adminPassword=admin --set edition=developer --set monitoringPasscode=$MONITORING_PASSCODE
  echo "✅ SonarQube installed in namespace '$NS_SONAR'."
else
  echo "✅ SonarQube is already installed in namespace '$NS_SONAR'."
fi

if [[ -z $(checkInstall prometheus "$NS_MONITORING") ]]; then
  echo "🔧 Installing Prometheus in namespace '$NS_MONITORING'..."
  helm install prometheus prometheus-community/prometheus --namespace $NS_MONITORING
  echo "✅ Prometheus installed in namespace '$NS_MONITORING'."
else
  echo "✅ Prometheus is already installed in namespace '$NS_MONITORING'."
fi

if [[ -z $(checkInstall grafana "$NS_MONITORING") ]]; then
  echo "🔧 Installing Grafana in namespace '$NS_MONITORING'..."
  helm install grafana grafana/grafana --namespace $NS_MONITORING
  echo "✅ Grafana installed in namespace '$NS_MONITORING'."
else
  echo "✅ Grafana is already installed in namespace '$NS_MONITORING'."
fi

kubectl delete pod jenkins-0 -n jenkins

echo "⏳ Waiting for pods to be ready..."

# Wait for all pods to be Running
for NS in $NS_JENKINS $NS_MONITORING $NS_SONAR; do
  while true; do
    NOT_RUNNING=$(kubectl get pods -n "$NS" --no-headers | awk '$3 != "Running"' | awk '$3 != "Completed"' || true)
    if [[ -n "$NOT_RUNNING" ]]; then
      echo "⏳ Waiting 5s more..."
      sleep 5
    else
      break
    fi
  done
done

kubectl -n $NS_JENKINS port-forward svc/jenkins 8080:8080 > /dev/null 2>&1 & echo $! > jenkins_port_forward.pid
kubectl -n $NS_JENKINS port-forward svc/localstack 4566:4566 > /dev/null 2>&1 & echo $! > localstack_port_forward.pid
kubectl -n $NS_SONAR port-forward sonarqube-sonarqube-0 9000:9000 > /dev/null 2>&1 & echo $! > sonarqube_port_forward.pid
kubectl -n $NS_MONITORING port-forward svc/grafana 3000:80 > /dev/null 2>&1 & echo $! > grafana_port_forward.pid
kubectl -n $NS_MONITORING port-forward svc/prometheus-server 9090:80 > /dev/null 2>&1 & echo $! > prometheus_port_forward.pid

echo "🚀 All services are up and running!"
echo " - Jenkins: http://localhost:8080 (Default credentials: admin/$(kubectl -n $NS_JENKINS get secret jenkins -o jsonpath="{.data.jenkins-admin-password}" | base64 --decode))"
echo " - SonarQube: http://127.0.0.1:9000/ (Default credentials: admin/admin)"
echo " - Grafana: http://localhost:3000 (Default credentials: admin/admin)"
echo " - Prometheus: http://localhost:9090"