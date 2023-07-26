#!/bin/bash

echo -e "\ncreate a kind cluster without default CNI"
cat <<EOF > cluster.yaml
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
networking:
  # the default CNI will not be installed
  disableDefaultCNI: true
EOF
kind create cluster --config=cluster.yaml

echo -e "\ninstall canal..."
kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.26.0/manifests/canal.yaml

echo -e "\ninstall multus..."
kubectl apply -f https://raw.githubusercontent.com/k8snetworkplumbingwg/multus-cni/master/deployments/multus-daemonset.yml -n kube-system

echo -e "\ninsert bridge CNI plugin..."
container_id=$(docker ps --filter "name=kind-*" -q)
wget -q https://github.com/yaocw2020/YAML/raw/main/harvester-netwokr-controller-integration-testing/bridge
chmod +x bridge
docker cp bridge "$container_id":/opt/cni/bin/bridge

echo -e "\ninstall harvester network controller..."
if ! (helm repo list | grep -q "harvester"); then
  helm repo add harvester https://charts.harvesterhci.io
  helm repo update
fi
kubectl create ns harvester-system
kubectl apply -f https://raw.githubusercontent.com/harvester/network-controller-harvester/master/manifests/dependency_crds/kubevirt.io_virtualmachineinstances.yaml
helm install harvester-network-controller harvester/harvester-network-controller -n harvester-system

sleep 2m

echo -e "\ninsert one more NIC into kind node"
secondnetwork="mynet1"
if ! (docker network ls | grep -q ${secondnetwork}); then
	docker network create -d bridge ${secondnetwork}
fi
docker network connect ${secondnetwork} ${container_id}

echo -e "\napply test case"
kubectl apply -f https://raw.githubusercontent.com/yaocw2020/YAML/main/harvester-netwokr-controller-integration-testing/test-case.yaml
