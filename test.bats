#!/usr/bin/env bats

@test "Check if docker is intalled" {
  run docker -v
  [ "$status" -eq 0 ]
}

@test "Check if kubectl is intalled" {
  run kubectl version --client
  [ "$status" -eq 0 ]
}

@test "Check if minikube is intalled" {
  run minikube version
  [ "$status" -eq 0 ]
}

@test "Check if helm is intalled" {
  run helm version
  [ "$status" -eq 0 ]
}

@test "Check if jenkins is up" {
  run curl -s -o /dev/null -w "%{http_code}" http://localhost:8080/login
  [ "$status" -eq 0 ]
  [ "$output" -eq 200 ]
}

@test "Check if localstack is up" {
  run curl -s -o /dev/null -w "%{http_code}" http://localhost:4566/_localstack/health
  [ "$status" -eq 0 ]
  [ "$output" -eq 200 ]
}