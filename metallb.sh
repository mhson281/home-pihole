#!/bin/bash
kubectl create namespace metallb-system

kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.13.11/config/manifests/metallb-native.yaml

