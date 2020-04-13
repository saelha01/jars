#!/bin/bash

function set_http_proxy() {
	export HTTP_PROXY=""
	export HTTPS_PROXY=""
}
function unset_http_proxy() {
	unset HTTP_PROXY
	unset HTTPS_PROXY
}

if ! [ -x "$(command -v kubectl)" ]; then
	curl -LO https://storage.googleapis.com/kubernetes-release/release/`curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt`/bin/linux/amd64/kubectl
	chmod +x ./kubectl
	mv ./kubectl /usr/local/bin/kubectl
fi
#kubectl apply -f seldon.crd.yaml || true

set_http_proxy
if ! [ -x "$(command -v helm)" ]; then
	curl https://get.helm.sh/helm-v3.1.2-linux-amd64.tar.gz -o helm-v3.1.2-linux-amd64.tar.gz
	tar -xzvf helm-v3.1.2-linux-amd64.tar.gz
	chmod a+x linux-amd64/helm
	mv linux-amd64/helm /usr/local/bin/
	rm -f helm-v3.1.2-linux-amd64.tar.gz
	rm -rf ./linux-amd64
fi

helm repo add ambassador https://www.getambassador.io
helm repo add seldon https://storage.googleapis.com/seldon-charts
helm repo add stable https://kubernetes-charts.storage.googleapis.com/
helm fetch ambassador/ambassador
helm fetch seldon/seldon-core-operator --version 1.0.3-SNAPSHOT
helm fetch stable/minio
unset_http_proxy

helm upgrade ambassador ./ambassador* --install --set service.type=NodePort
helm upgrade seldon-core ./seldon-core-operator* --install --set ambassador.enabled=true --set crd.create=true --set certManager.enabled=false --set usageMetrics.enabled=false

kubectl wait --for=condition=available deploy/ambassador --timeout=4m
MASTER_IP=$(kubectl get nodes -o wide | grep master | awk '{print $6}')
MINIO_NODE_PORT=$(kubectl get svc minio -o jsonpath='{ .spec.ports[0].nodePort }')
MINIO_ACCESS_KEY_PATH="minio.access.key"
MINIO_SECRET_KEY_PATH="minio.secret.key"
if [[ ! -f "${MINIO_ACCESS_KEY_PATH}" ]]; then
	head -c 4096 /dev/urandom | LC_CTYPE=C tr -cd 'a-zA-Z0-9' | head -c 64 > "minio.access.key"
	head -c 4096 /dev/urandom | LC_CTYPE=C tr -cd 'a-zA-Z0-9' | head -c 64 > "minio.secret.key"
fi
MINIO_ACCESS_KEY="$(cat ${MINIO_ACCESS_KEY_PATH})"
MINIO_SECRET_KEY="$(cat ${MINIO_SECRET_KEY_PATH})"
helm upgrade minio ./minio-* --install --set accessKey=${MINIO_ACCESS_KEY} --set secretKey=${MINIO_SECRET_KEY} --set service.type=NodePort --set persistence.enabled=false

rm -f seldon-core-operator*
rm -f ambassador-*
rm -f minio-*

kubectl delete secret seldon-init-container-secret || true
kubectl create secret generic seldon-init-container-secret \
    --from-literal=AWS_ENDPOINT_URL="http://minio.default:9000" \
    --from-literal=AWS_ACCESS_KEY_ID="${MINIO_ACCESS_KEY}" \
    --from-literal=AWS_SECRET_ACCESS_KEY="${MINIO_SECRET_KEY}" \
    --from-literal=USE_SSL=false

if ! [ -x "$(command -v mc)" ]; then
	curl https://dl.min.io/client/mc/release/linux-amd64/mc -o mc
	mv mc /usr/local/bin/
	chmod a+x /usr/local/bin/mc
fi

kubectl wait --for=condition=available deploy/minio --timeout=4m
sleep 10
mc config host rm seldon-models 
mc config host add seldon-models http://${MASTER_IP}:${MINIO_NODE_PORT}/ ${MINIO_ACCESS_KEY} ${MINIO_SECRET_KEY}
mc mb seldon-models/test || true
mc cp elasticnet_wine/conda.yaml seldon-models/test/elasticnet_wine/conda.yaml
mc cp elasticnet_wine/MLmodel seldon-models/test/elasticnet_wine/MLmodel
mc cp elasticnet_wine/model.pkl seldon-models/test/elasticnet_wine/model.pkl 
kubectl apply -f minio_model.yaml

#kubectl apply -f seldon.crd.yaml || true
# kubectl wait --for=condition=available deploy/seldon-controller-manager --timeout=4m
# kubectl apply -f minio_model.yaml
# sleep 5
# kubectl wait --for=condition=available deploy/mlflow-default-0-classifier --timeout=4m
# PODID=$(kubectl get pods | grep classifier | awk '{print $1}')
# kubectl port-forward ${PODID} 80:9000 &
# sleep 5

# curl localhost/api/v1.0/predictions -H 'Content-Type: application/json'     -d '{ "data": { "ndarray": [[7.0, 0.27, 0.36, 20.7, 0.045, 45.0, 170.0, 1.001, 3.0, 0.45, 8.8]] } }' -X POST

# ps | grep kubectl | awk '{print $1}' | xargs -i kill -9 {}

