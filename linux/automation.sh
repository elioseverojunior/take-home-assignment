#!/usr/bin/env bash

set -eo pipefail

SCRIPT_NAME=${0##*/}

# Parameters
BUILD_DOCKER_IMAGES=true
MINIKUBE_SERVICE_URL=true
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

# Reset
NC='\033[0m'

# Regular Colors
Black='\033[0;30m'        # Black
Red='\033[0;31m'          # Red
Green='\033[0;32m'        # Green
Yellow='\033[0;33m'       # Yellow
Blue='\033[0;34m'         # Blue
Purple='\033[0;35m'       # Purple
Cyan='\033[0;36m'         # Cyan
White='\033[0;37m'        # White

# Bold
BBlack='\033[1;30m'       # Black
BRed='\033[1;31m'         # Red
BGreen='\033[1;32m'       # Green
BYellow='\033[1;33m'      # Yellow
BBlue='\033[1;34m'        # Blue
BPurple='\033[1;35m'      # Purple
BCyan='\033[1;36m'        # Cyan
BWhite='\033[1;37m'       # White

# Underline
UBlack='\033[4;30m'       # Black
URed='\033[4;31m'         # Red
UGreen='\033[4;32m'       # Green
UYellow='\033[4;33m'      # Yellow
UBlue='\033[4;34m'        # Blue
UPurple='\033[4;35m'      # Purple
UCyan='\033[4;36m'        # Cyan
UWhite='\033[4;37m'       # White

# Background
On_Black='\033[40m'       # Black
On_Red='\033[41m'         # Red
On_Green='\033[42m'       # Green
On_Yellow='\033[43m'      # Yellow
On_Blue='\033[44m'        # Blue
On_Purple='\033[45m'      # Purple
On_Cyan='\033[46m'        # Cyan
On_White='\033[47m'       # White

# High Intensity
IBlack='\033[0;90m'       # Black
IRed='\033[0;91m'         # Red
IGreen='\033[0;92m'       # Green
IYellow='\033[0;93m'      # Yellow
IBlue='\033[0;94m'        # Blue
IPurple='\033[0;95m'      # Purple
ICyan='\033[0;96m'        # Cyan
IWhite='\033[0;97m'       # White

# Bold High Intensity
BIBlack='\033[1;90m'      # Black
BIRed='\033[1;91m'        # Red
BIGreen='\033[1;92m'      # Green
BIYellow='\033[1;93m'     # Yellow
BIBlue='\033[1;94m'       # Blue
BIPurple='\033[1;95m'     # Purple
BICyan='\033[1;96m'       # Cyan
BIWhite='\033[1;97m'      # White

# High Intensity backgrounds
On_IBlack='\033[0;100m'   # Black
On_IRed='\033[0;101m'     # Red
On_IGreen='\033[0;102m'   # Green
On_IYellow='\033[0;103m'  # Yellow
On_IBlue='\033[0;104m'    # Blue
On_IPurple='\033[0;105m'  # Purple
On_ICyan='\033[0;106m'    # Cyan
On_IWhite='\033[0;107m'   # White

function decrypt() {
  echo $(echo "${1}" | base64 -d)
}

function show_message() {
  message="$1"
  separator="*"
  width=$((${#message} + 6))
  echo; echo -e "${BIGreen}"; printf %.s${separator} $(seq 1 ${width}); echo
  echo "-> ${message} <-"
  printf %.s${separator} $(seq 1 ${width}); echo -e "${NC}"
}

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
    Required Parameters:
    Optional Parameters:
      -i|--image                      <docker image>                  Default is ${MY_NEW_IMAGE}
      --no-build-docker-images        <no build docker new image>     Default is ${BUILD_DOCKER_IMAGES}
      --no-push-docker-images         <no push docker new image>      Default is ${PUSH_DOCKER_IMAGES}
      --no-run-minikube               <no run minikube deployment>    Default is ${RUN_MINIKUBE}
      --no-run-terraform              <no run terraform deployment>   Default is ${RUN_TERRAFORM}
      --no-open-minikube-service-url  <no open minikube service url>  Default is ${MINIKUBE_SERVICE_URL}
      --start-minikube-dashboard      <start minikube dashboard>      Default is ${START_MINIKUBE_DASHBOARD}
      -h|--help                       <display this help>
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
  show_message "Checking Minikube Status"
  echo -e "$(minikube status)"

  if [[ -z "$(minikube_status_json)" ]];
  then
    show_message "Deploying minikube cluster..."
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
    show_message "✅Checking Minikube Status"
    echo -e "$(minikube_status)"
  done
  show_message "👍Minikube is ready for use..."
  show_message "Listing current Minikube Addons..."
  minikube addons list
  if [[ "${START_MINIKUBE_DASHBOARD}" == "true" ]];
  then
    show_message "👍Enabling Minikube Dashboard..."
    minikube dashboard &
  fi
}

function terraform_deployment() {
  cd ${TERRAFORM_DIR}
  show_message "Applying Terraform Format Command"; terraform fmt -recursive=true\
    && show_message "Initializing Terraform Code"; terraform init\
    && show_message "Validating Terraform Code"; terraform validate\
    && show_message "Planning Terraform Code"; terraform plan -input=false\
    && show_message "Applying Terraform Code"; terraform apply -input=false -auto-approve\
  ;
  cd ${CWD}
}

function script_yaml_image_tag_updater() {
  show_message "Updating $(pwd)/script.yaml -> $(pwd)/new-app.yaml"
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

  show_message "Initializing Dockerize Dependencies: Namespace, MySQL Database"
  kubectl apply\
    -f "$(pwd)/namespace.yaml"\
    -f "$(pwd)/configmaps_scripts.yaml"\
    -f "$(pwd)/configmaps_sql.yaml"\
    -f "$(pwd)/secrets.yaml"\
    -f "$(pwd)/mysql.yaml";

  if [[ "${RUN_TERRAFORM}" == "true" ]];
  then
    terraform_deployment
  fi

  if [[ "${MINIKUBE_SERVICE_URL}" == "true" ]];
  then
    minikube service ${APPLICATION} -n webserver-assessment
  fi

  show_message "Executing diff in new-app.yaml"
  kubectl diff -f new-app.yaml 2>&1 > "$(pwd)/deployment-diff.txt"

  cd ${CWD}

  show_message "✅ Done."
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
      --no-open-minikube-service-url)
        MINIKUBE_SERVICE_URL=false
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
