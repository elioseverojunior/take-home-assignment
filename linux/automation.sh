#!/usr/bin/env bash

set -eo pipefail

# Environments
## Directories
CWD=$(pwd)
APPLICATION_DIR="$(pwd)/../dockerize"
KUBERNETES_DIR="$(pwd)/../kubernetes"
TERRAFORM_DIR="$(pwd)/../terraform/tf-kubernetes-deployment"
LINUX_DIR="$(pwd)/../linux"

## Docker
PROJECT=${PROJECT:-dockerize}
APPLICATION=${APPLICATION:-dockerize}
ORGANIZATION=${ORGANIZATION:-elioseverojunior}
REGISTRY="${ORGANIZATION}/${APPLICATION}"
HTTP_PORT=${HTTP_PORT:-8080}
TAG=latest

## Build
GOOS=$(uname | tr '[:upper:]' '[:lower:]')
GOARCH=${GOARCH:-amd64}
COMMIT=$(git rev-parse HEAD)
SHORT_COMMIT=$(git rev-parse --short HEAD)
BUILD_TIME=$(date -u '+%Y-%m-%d_%H:%M:%S')
BRANCH_NAME=$(git name-rev --refs="refs/heads/*" --name-only ${COMMIT})
RELEASE_VERSION=${RELEASE_VERSION:-0.0.1}
RELEASE=${RELEASE_VERSION}-${BRANCH_NAME}-${SHORT_COMMIT}

# Functions
function docker_tag() {
  docker tag ${REGISTRY}:${TAG} ${REGISTRY}:${BRANCH_NAME}\
    && docker tag ${REGISTRY}:latest ${REGISTRY}:${RELEASE}\
  ;
}

function docker_build() {
  cd ${APPLICATION_DIR}
  echo "Building Docker: ${REGISTRY}:${TAG}";
  docker build  -f "Dockerfile" -t ${REGISTRY}:${TAG} --no-cache --progress=plain\
    --build-arg APPLICATION=${APPLICATION}\
    --build-arg RELEASE=${RELEASE}\
    --build-arg COMMIT=${COMMIT}\
    --build-arg BUILD_TIME=${BUILD_TIME} .\
  && docker_tag;
  cd ${CWD}
}

function docker_push() {
  echo "Pushing to Docker: ${REGISTRY}:${TAG}"; docker push ${REGISTRY}:${TAG}; echo -e "\n"
  echo "Pushing to Docker: ${REGISTRY}:${BRANCH_NAME}"; docker push ${REGISTRY}:${BRANCH_NAME}; echo -e "\n"
  echo "Pushing to Docker: ${REGISTRY}:${RELEASE}"; docker push ${REGISTRY}:${RELEASE}; echo -e "\n"
}

function minikube_status_check_apiserver() {
  echo $(minikube status -o json | jq -Sr '.APIServer')
}

function minikube_status_check_host() {
  echo $(minikube status -o json | jq -Sr '.Host')
}

function minikube_status_check_kubeconfig() {
  echo $(minikube status -o json | jq -Sr '.Kubeconfig')
}

function minikube_status_check_kubelet() {
  echo $(minikube status -o json | jq -Sr '.Kubelet')
}

function minikube_status() {
  echo "$(minikube status)"
}

function minikube_status_json() {
  echo "$(minikube status -o json | jq 'try(select (.Name != null))')"
}

function minikube_deployment() {
  echo -e "Checking Minikube Status: $(minikube status)\n"
  if [[ -z "$(minikube_status_json)" ]];
  then
    echo -e "Deploying minikube cluster..."
    echo -e "🔑Your root password will be requested"
    minikube start\
      --driver=hyperkit\
      --memory=16384\
      --cpus=4\
      --disk-size=100g\
      --install-addons=true\
      --addons=helm-tiller\
      --addons=metrics-server\
      --addons=dashboard\
      --addons=pod-security-policy\
      --delete-on-failure;
  fi
  while [[ ! -z "$(minikube_status_json)"\
    && "$(minikube_status_check_host)" != "Running"\
    && "$(minikube_status_check_kubelet)" != "Running"\
    && "$(minikube_status_check_apiserver)" != "Running"\
    && "$(minikube_status_check_kubeconfig)" != "Configured"
  ]];
  do
    sleep 10;
    echo -e "✅Checking Minikube Status: $(minikube_status)\n"
  done
  echo -e "👍Minikube is ready for use...\n"
  minikube dashboard &
}

function terraform_deployment() {
  cd ${TERRAFORM_DIR}
  echo -e "\nApplying Terraform Format Command"; terraform fmt -recursive=true\
    && echo -e "\nInitializing Terraform Code"; terraform init\
    && echo -e "\nValidating Terraform Code"; terraform validate\
    && echo -e "\nPlanning Terraform Code"; terraform plan -input=false\
    && echo -e "\nApplying Terraform Code"; terraform apply -input=false\
  ;
  cd ${CWD}
}

function main() {
  docker_build
  docker_push
  minikube_deployment
  terraform_deployment
  cd ${CWD}
}

time main
