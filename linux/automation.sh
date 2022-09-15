#!/usr/bin/env bash

set -eo pipefail

SCRIPT_NAME=${0##*/}

# Parameters
BUILD_DOCKER_IMAGES=true
MY_NEW_IMAGE=elioseverojunior/dockerize:latest
PUSH_DOCKER_IMAGES=true
RUN_MINIKUBE=true
RUN_TERRAFORM=true
START_MINIKUBE_DASHBOARD=false

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

function validate_required() {
    if [[ -z "$1" ]];
    then
        echo -"Argument $2 is required. Exiting..."
        exit
    fi
}

function on_help() {
    cat <<-EOF
USAGE:
  ${SCRIPT_NAME}
    -i|--image                  <docker image>                Default is ${MY_NEW_IMAGE}
    --no-build-docker-images    <no build docker new image>   Default is ${BUILD_DOCKER_IMAGES}
    --no-push-docker-images     <no push docker new image>    Default is ${PUSH_DOCKER_IMAGES}
    --no-run-minikube           <no run minikube deployment>  Default is ${RUN_MINIKUBE}
    --no-run-terraform          <deploy with terraform>       Default is ${RUN_TERRAFORM}
    --start-minikube-dashboard  <start minikube dashboard>    Default is ${START_MINIKUBE_DASHBOARD}
    -h|--help                   <display this help>
EOF
}

# Functions
function docker_tag() {
  echo -e "Generating Docker Tags";
  echo -e "Docker Tag: ${REGISTRY}:${BRANCH_NAME}"; docker tag ${REGISTRY}:${TAG} ${REGISTRY}:${BRANCH_NAME}
  echo -e "Docker Tag: ${REGISTRY}:${RELEASE}"; docker tag ${REGISTRY}:latest ${REGISTRY}:${RELEASE}
}

function docker_build() {
  cd ${APPLICATION_DIR}
  echo -e "Building Docker: ${REGISTRY}:${TAG}";
  docker build  -f "Dockerfile" -t ${REGISTRY}:${TAG} --no-cache --progress=plain\
    --build-arg APPLICATION=${APPLICATION}\
    --build-arg RELEASE=${RELEASE}\
    --build-arg COMMIT=${COMMIT}\
    --build-arg BUILD_TIME=${BUILD_TIME}\
    .\
  && docker_tag;
  cd ${CWD}
}

function docker_push() {
  echo -e "Pushing to Docker: ${REGISTRY}:${TAG}"; docker push ${REGISTRY}:${TAG}; echo -e "\n"
  echo -e "Pushing to Docker: ${REGISTRY}:${BRANCH_NAME}"; docker push ${REGISTRY}:${BRANCH_NAME}; echo -e "\n"
  echo -e "Pushing to Docker: ${REGISTRY}:${RELEASE}"; docker push ${REGISTRY}:${RELEASE}; echo -e "\n"
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
  echo -e "Listing current Minikube Addons...\n"
  minikube addons list
  if [[ "${START_MINIKUBE_DASHBOARD}" == "true" ]];
  then
    echo -e "👍Enabling Minikube Dashboard...\n"
    minikube dashboard &
  fi
}

function terraform_deployment() {
  cd ${TERRAFORM_DIR}
  echo -e "\nApplying Terraform Format Command"; terraform fmt -recursive=true\
    && echo -e "\nInitializing Terraform Code"; terraform init\
    && echo -e "\nValidating Terraform Code"; terraform validate\
    && echo -e "\nPlanning Terraform Code"; terraform plan -input=false\
    && echo -e "\nApplying Terraform Code"; terraform apply -input=false -auto-approve\
  ;
  cd ${CWD}
}

function script_yaml_image_tag_updater() {
  echo -e "Updating $(pwd)/script.yaml -> $(pwd)/new-app.yaml"
  sed "s|MY_NEW_IMAGE|${MY_NEW_IMAGE}|g" "$(pwd)/script.yaml" > "$(pwd)/new-app.yaml"
}

function main() {
  script_yaml_image_tag_updater
  if [[ "${BUILD_DOCKER_IMAGES}" == "true" ]];
  then
    docker_build
  fi

  if [[ "${PUSH_DOCKER_IMAGES}" == "true" ]];
  then
    docker_push
  fi

  if [[ "${RUN_MINIKUBE}" == "true" ]];
  then
    minikube_deployment
  fi

  if [[ "${RUN_TERRAFORM}" == "true" ]];
  then
    terraform_deployment
  fi

  echo -e "Executing diff in new-app.yaml"
  kubectl diff -f new-app.yaml 2>&1 > "$(pwd)/deployment-diff.txt"

  cd ${CWD}

  echo -e "✅ Done.\n"
}

while [[ $# -gt 0 ]]
do
  key="$1"

  case $key in
      -i|--image)
        MY_NEW_IMAGE=$2
        shift # past argument
        shift # past value
      ;;
      --start-minikube-dashboard)
        START_MINIKUBE_DASHBOARD=true
        shift # past argument
      ;;
      --no-run-terraform)
        RUN_TERRAFORM=false
        shift # past argument
      ;;
      --no-run-minikube)
        RUN_MINIKUBE=false
        shift # past argument
      ;;
      --no-build-docker-images)
        BUILD_DOCKER_IMAGES=false
        shift # past argument
      ;;
      --no-push-docker-images)
        PUSH_DOCKER_IMAGES=false
        shift # past argument
      ;;
      -h|--help)
        on_help
        shift # past argument
        shift # past value
        exit 0
      ;;
      *)
        if [[ ! -z "$2" ]]
        then
            echo "Parameter: \"$1\" with Value: \"$2\" is not recognized"
            exit 1
        elif [[ ! -z "$1" ]]
        then
            echo "Parameter: \"$1\" is not recognized"
            exit 1
        fi
        shift # past argument
        shift # past value
      ;;
  esac
done

time main
