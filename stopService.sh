#!/bin/bash

set -e

echo "🛑 Deteniendo Jenkins..."

kill $(cat jenkins_port_forward.pid)
rm jenkins_port_forward.pid

echo "🛑 Deteniendo Localstack..."

kill $(cat localstack_port_forward.pid)
rm localstack_port_forward.pid

echo "🛑 Deteniendo Minikube..."
minikube stop

echo "✅ Jenkins y Minikube detenidos correctamente."
