#!/bin/bash

curl -LO https://storage.googleapis.com/kubernetes-release/release/`curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt`/bin/linux/amd64/kubectl
chmod +x ./kubectl
mv ./kubectl /usr/local/bin/kubectl
#kubectl apply -f seldon.crd.yaml || true

curl https://get.helm.sh/helm-v3.1.2-linux-amd64.tar.gz -o helm-v3.1.2-linux-amd64.tar.gz
tar -xzvf helm-v3.1.2-linux-amd64.tar.gz
chmod a+x linux-amd64/helm
mv linux-amd64/helm /usr/local/bin/

helm repo add ambassador https://www.getambassador.io
helm repo add seldon https://storage.googleapis.com/seldon-charts

helm fetch ambassador/ambassador
helm fetch seldon/seldon-core-operator --version 1.0.3-SNAPSHOT

helm upgrade ambassador ./ambassador* --install
helm upgrade seldon-core ./seldon-core-operator* --install --set ambassador.enabled=true --set crd.create=true --set certManager.enabled=false --set usageMetrics.enabled=false

#kubectl apply -f seldon.crd.yaml || true
kubectl wait --for=condition=available deploy/seldon-controller-manager --timeout=4m
kubectl apply -f model.yaml
sleep 5
kubectl wait --for=condition=available deploy/mlflow-default-0-classifier --timeout=4m
PODID=$(kubectl get pods | grep classifier | awk '{print $1}')
kubectl port-forward ${PODID} 80:9000 &
sleep 5

curl localhost/api/v1.0/predictions -H 'Content-Type: application/json'     -d '{ "data": { "ndarray": [[7.0, 0.27, 0.36, 20.7, 0.045, 45.0, 170.0, 1.001, 3.0, 0.45, 8.8]] } }' -X POST

ps | grep kubectl | awk '{print $1}' | xargs -i kill -9 {}

