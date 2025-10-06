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