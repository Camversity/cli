#!/bin/bash

GOOGLE_ACCOUNT_JSON_VAR="";
GOOGLE_PROJECT_ID_VAR="";
GOOGLE_COMPUTE_ZONE_VAR="";
GOOGLE_CLUSTER_NAME_VAR="";
PROJECT_NAME_VAR="";
CIRCLE_SHA1_VAR="";
SHOW_VAR="";


GOOGLE_ACCOUNT_JSON_ARG="";
GOOGLE_PROJECT_ID_ARG="";
GOOGLE_COMPUTE_ZONE_ARG="";
GOOGLE_CLUSTER_NAME_ARG="";
PROJECT_NAME_ARG="";
CIRCLE_SHA1_ARG="";

DO_ACTION="";


function usage()
{
  echo "FORMAT: ./deploy.sh  ACTION [ PARAMETERS ]"
  echo "ACTIONS: login, build-docker, push-docker, deploy, rollout-status, rollback"
  echo "parameters override env vars"
  echo "PARAMETERS:"
  echo "--google-account-json=json_string"
  echo "--google-project-id=project_id(on google)"
  echo "--google-compute-zone=compute_zone"
  echo "--google-cluster-name=cluster_name"
  echo "--project-name=project_name(app name)"
  echo "--commit-hash=full commit sha hash"
  echo "--show-var  shows the variables if set"
}


function read_env_vars()
{
  GOOGLE_ACCOUNT_JSON_VAR=$GOOGLE_ACCOUNT_JSON;
  GOOGLE_PROJECT_ID_VAR=$GOOGLE_PROJECT_ID;
  GOOGLE_COMPUTE_ZONE_VAR=$GOOGLE_COMPUTE_ZONE;
  GOOGLE_CLUSTER_NAME_VAR=$GOOGLE_CLUSTER_NAME;
  PROJECT_NAME_VAR=$PROJECT_NAME;
  CIRCLE_SHA1_VAR=$CIRCLE_SHA1;
}


function read_args()
{
  while [ "$1" != "" ]; do

    PARAM=`echo $1 | awk -F= '{print $1}'`
    VALUE=`echo $1 | awk -F= '{print $2}'`

    case $PARAM in
      -h | --help)
        usage
        exit
        ;;
      --google-account-json)
        GOOGLE_ACCOUNT_JSON_ARG=$VALUE
        ;;
      --google-project-id)
        GOOGLE_PROJECT_ID_ARG=$VALUE
        ;;
      --google-compute-zone)
        GOOGLE_COMPUTE_ZONE_ARG=$VALUE
        ;;
      --google-cluster-name)
        GOOGLE_CLUSTER_NAME_ARG=$VALUE
        ;;
      --project-name)
        PROJECT_NAME_ARG=$VALUE
        ;;
      --commit-hash)
        CIRCLE_SHA1_ARG=$VALUE
        ;;
      --show-var)
        SHOW_VAR="yes"
        ;;
      login)
        DO_ACTION="login"
        ;;
      build-docker)
        DO_ACTION="build-docker"
        ;;
      push-docker)
        DO_ACTION="push-docker"
        ;;
      deploy)
        DO_ACTION="deploy"
        ;;
      rollout-status)
        DO_ACTION="rollout-status"
        ;;
      rollback)
        DO_ACTION="rollback"
        ;;
      *)
        echo "ERROR: unknown parameter \"$PARAM\""
        echo "deploy -h for usage";
        exit 1
        ;;
    esac
    shift
  done

}

function override_env_vars()
{
  if [ ! -z "$GOOGLE_ACCOUNT_JSON_ARG" ]; then GOOGLE_ACCOUNT_JSON_VAR=$GOOGLE_ACCOUNT_JSON_ARG; fi;
  if [ ! -z "$GOOGLE_PROJECT_ID_ARG" ]; then GOOGLE_PROJECT_ID_VAR=$GOOGLE_PROJECT_ID_ARG; fi;
  if [ ! -z "$GOOGLE_COMPUTE_ZONE_ARG" ]; then GOOGLE_COMPUTE_ZONE_VAR=$GOOGLE_COMPUTE_ZONE_ARG; fi;
  if [ ! -z "$GOOGLE_CLUSTER_NAME_ARG" ]; then GOOGLE_CLUSTER_NAME_VAR=$GOOGLE_CLUSTER_NAME_ARG; fi;
  if [ ! -z "$PROJECT_NAME_ARG" ]; then PROJECT_NAME_VAR=$PROJECT_NAME_ARG; fi;
  if [ ! -z "$CIRCLE_SHA1_ARG" ]; then CIRCLE_SHA1_VAR=$CIRCLE_SHA1_ARG; fi;

}


function check_action()
{
  if [ -z "$DO_ACTION" ];
  then
    echo "no action specified";
    echo "deploy -h for usage";
    exit;
  fi;
}


function process_action()
{
  case $DO_ACTION in
    -h | --help)
      usage
      exit
      ;;
    login)
      login
      exit
      ;;
    build-docker)
      build_docker;
      ;;
    push-docker)
      push_docker
      ;;
    deploy)
      deploy
      ;;
    rollout-status)
      rollout_status;
      ;;
    rollback)
      rollback;
      ;;
    *)
      echo "ERROR: unknown action \"$DO_ACTION\""
      echo "deploy -h for usage";
      exit 1
      ;;
  esac
}

function login()
{
  if [ -n "$GOOGLE_ACCOUNT_JSON_VAR" -a -n "$GOOGLE_PROJECT_ID_VAR" -a -n "$GOOGLE_COMPUTE_ZONE_VAR" -a -n "$GOOGLE_CLUSTER_NAME_VAR" ];
  then
    echo "${GOOGLE_ACCOUNT_JSON_VAR}" > account.json;
    gcloud auth activate-service-account --key-file account.json;
    gcloud --quiet config set project ${GOOGLE_PROJECT_ID_VAR};
    gcloud --quiet config set compute/zone ${GOOGLE_COMPUTE_ZONE_VAR};
    gcloud --quiet container clusters get-credentials ${GOOGLE_CLUSTER_NAME_VAR};
  else
    echo "ERROR: needs account_json, project_id, compute_zone, cluster_name - deploy.sh -h for usage";
  fi;
  exit;
}

function build_docker()
{
  if [ -n "${GOOGLE_PROJECT_ID_VAR}" -a -n "${PROJECT_NAME_VAR}" -a -n "${CIRCLE_SHA1_VAR}" ];
  then
    export DOCKER_NAME="gcr.io/${GOOGLE_PROJECT_ID_VAR}/${PROJECT_NAME_VAR}";
    export DOCKER_TAG="${DOCKER_NAME}:${CIRCLE_SHA1_VAR}";
    docker build -f Dockerfile.prod -t ${DOCKER_TAG} .;
    docker tag ${DOCKER_TAG} ${DOCKER_NAME}:latest;
  else
    echo "ERROR: needs project_id, project_name, commit_hash - deploy.sh -h for usage";
  fi;
  exit;
}

function push_docker()
{
  if [ -n "${GOOGLE_PROJECT_ID_VAR}" -a -n "${PROJECT_NAME_VAR}" -a -n "${CIRCLE_SHA1_VAR}" ];
  then
    export DOCKER_NAME="gcr.io/${GOOGLE_PROJECT_ID_VAR}/${PROJECT_NAME_VAR}";
    export DOCKER_TAG="${DOCKER_NAME}:${CIRCLE_SHA1_VAR}";
    gcloud docker -- push ${DOCKER_TAG}
    gcloud docker -- push ${DOCKER_NAME}:latest
  else
    echo "ERROR: needs project_id, project_name, commit_hash - deploy.sh -h for usage";

  fi;
  exit;
}

function deploy()
{
  if [ -n "${GOOGLE_PROJECT_ID_VAR}" -a -n "${PROJECT_NAME_VAR}" -a -n "${CIRCLE_SHA1_VAR}" ];
  then
    export DOCKER_NAME="gcr.io/${GOOGLE_PROJECT_ID_VAR}/${PROJECT_NAME_VAR}";
    export DOCKER_TAG="${DOCKER_NAME}:${CIRCLE_SHA1_VAR}";
    kubectl set image deployment/${PROJECT_NAME_VAR} ${PROJECT_NAME_VAR}=${DOCKER_TAG} --record
  else
    echo "ERROR: needs project_id, project_name, commit_hash - deploy.sh -h for usage";

  fi;
  exit;
}


function rollout_status()
{
  if [ -n "${PROJECT_NAME_VAR}" ];
  then
    kubectl rollout status deployment ${PROJECT_NAME_VAR}
  else
    echo "ERROR: needs project_name - deploy.sh -h for usage";
  fi;
  exit;
}


function rollback()
{
  if [ -n "${PROJECT_NAME_VAR}" ];
  then
    kubectl rollout undo deployment/${PROJECT_NAME_VAR}
  else
    echo "ERROR: needs project_name  - deploy.sh -h for usage";
  fi;
  exit;
}

function show-var()
{
  if [ ! -z "${SHOW_VAR}" ];
  then
    export GOOGLE_ACCOUNT_JSON=$GOOGLE_ACCOUNT_JSON_VAR;
    export GOOGLE_PROJECT_ID=$GOOGLE_PROJECT_ID_VAR;
    export GOOGLE_COMPUTE_ZONE=$GOOGLE_COMPUTE_ZONE_VAR;
    export GOOGLE_CLUSTER_NAME=$GOOGLE_CLUSTER_NAME_VAR;
    export PROJECT_NAME=$PROJECT_NAME_VAR;
    export CIRCLE_SHA1=$CIRCLE_SHA1_VAR;

    echo "project_id:" $GOOGLE_PROJECT_ID;
    echo "compute_zone: "$GOOGLE_COMPUTE_ZONE;
    echo "cluster_name: "$GOOGLE_CLUSTER_NAMEG;
    echo "project_name: "$PROJECT_NAME;
    echo "commit_hash: "$CIRCLE_SHA1;
    echo "action: "$DO_ACTION;


  fi;
}

read_args "$@";

read_env_vars;

override_env_vars;

show-var;

check_action;

process_action;
