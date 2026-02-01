#!/bin/bash

set -e

echo "🛑 Deteniendo Jenkins..."

kill "$(cat jenkins_port_forward.pid)"
rm jenkins_port_forward.pid

echo "🛑 Deteniendo Localstack..."

kill "$(cat localstack_port_forward.pid)"
rm localstack_port_forward.pid

echo "🛑 Deteniendo SonarQube..."

kill "$(cat sonarqube_port_forward.pid)"
rm sonarqube_port_forward.pid

echo "🛑 Deteniendo Grafana..."

kill "$(cat grafana_port_forward.pid)"
rm grafana_port_forward.pid

echo "🛑 Deteniendo Prometheus..."

kill "$(cat prometheus_port_forward.pid)"
rm prometheus_port_forward.pid

echo "🛑 Deteniendo Minikube..."
minikube stop

echo "✅ Entorno detenido correctamente."
