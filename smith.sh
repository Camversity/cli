#!/bin/bash

GOOGLE_ACCOUNT_JSON_VAR="";
GOOGLE_PROJECT_ID_VAR="";
GOOGLE_COMPUTE_ZONE_VAR="";
GOOGLE_CLUSTER_NAME_VAR="";
PROJECT_NAME_VAR="";
CIRCLE_SHA1_VAR="";
CIRCLE_BUILD_URL_VAR="";
CIRCLE_BUILD_NUM_VAR="";
CIRCLE_PROJECT_REPONAME_VAR="";
CIRCLE_PROJECT_USERNAME_VAR="";
REPORT_URL_VAR="";
REPORT_URL_CHANNEL_VAR="";
SHOW_VAR="";
DEPLOY_TIMEOUT_VAR="";


GOOGLE_ACCOUNT_JSON_ARG="";
GOOGLE_PROJECT_ID_ARG="";
GOOGLE_COMPUTE_ZONE_ARG="";
GOOGLE_CLUSTER_NAME_ARG="";
PROJECT_NAME_ARG="";
CIRCLE_SHA1_ARG="";
REPORT_URL_ARG="";
REPORT_URL_CHANNEL_ARG="";
DEPLOY_TIMEOUT_ARG="";

DO_ACTION="";
DEPLOY_STATUS="";


function usage()
{
  echo "FORMAT: $0  ACTION [ PARAMETERS ]"
  echo "ACTIONS: login, build-docker, push-docker, deploy, rollout-status, report-status, rollback"
  echo "parameters override env vars"
  echo "PARAMETERS:"
  echo "--google-account-json=json_string"
  echo "--google-project-id=project_id(on google)"
  echo "--google-compute-zone=compute_zone"
  echo "--google-cluster-name=cluster_name"
  echo "--project-name=project_name(app name)"
  echo "--commit-hash=full commit sha hash"
  echo "--report-url=web_destination"
  echo "--report-channel=channel"
  echo "--show-var  shows the variables if set"
  echo "--deploy-timeout  time in seconds to wait for deployment to finish - default 300"
}


function read_env_vars()
{
  GOOGLE_ACCOUNT_JSON_VAR=$GOOGLE_ACCOUNT_JSON;
  GOOGLE_PROJECT_ID_VAR=$GOOGLE_PROJECT_ID;
  GOOGLE_COMPUTE_ZONE_VAR=$GOOGLE_COMPUTE_ZONE;
  GOOGLE_CLUSTER_NAME_VAR=$GOOGLE_CLUSTER_NAME;
  PROJECT_NAME_VAR=$PROJECT_NAME;
  CIRCLE_SHA1_VAR=$CIRCLE_SHA1;
  CIRCLE_BUILD_URL_VAR=${CIRCLE_BUILD_URL};
  CIRCLE_BUILD_NUM_VAR=${CIRCLE_BUILD_NUM};
  CIRCLE_PROJECT_REPONAME_VAR=${CIRCLE_PROJECT_REPONAME}
  CIRCLE_PROJECT_USERNAME_VAR=${CIRCLE_PROJECT_USERNAME}
  REPORT_URL_VAR=$REPORT_URL;
  REPORT_URL_CHANNEL_VAR=$REPORT_URL_CHANNEL;
  DEPLOY_TIMEOUT_VAR=${DEPLOY_TIMEOUT:-300};
}


function read_args()
{
  while [ "$1" != "" ]; do

    PARAM=`echo $1 | awk -F= '{print $1}'`
    VALUE=`echo $1 | awk -F= '{print $2}'`

    case $PARAM in
      -h | --help)
        usage "$@"
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
      --report-url)
        REPORT_URL_ARG=$VALUE
        ;;
      --report-channel)
        REPORT_URL_CHANNEL_ARG=$VALUE
        ;;
      --deploy-timeout)
        DEPLOY_TIMEOUT_ARG=$VALUE
        ;;
      --show-var)
        SHOW_VAR="yes"
        ;;
      login)
        DO_ACTION="login"
        ;;
      login-docker)
        DO_ACTION="login-docker"
        ;;
      login-kube)
        DO_ACTION="login-kube"
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
      report-status)
          DO_ACTION="report-status"
          ;;
      rollback)
        DO_ACTION="rollback"
        ;;
      *)
        echo "ERROR: unknown parameter \"$PARAM\""
        echo "$0 -h for usage";
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
  if [ ! -z "$REPORT_URL_ARG" ]; then REPORT_URL_VAR=$REPORT_URL_ARG; fi;
  if [ ! -z "$REPORT_URL_CHANNEL_ARG" ]; then REPORT_URL_CHANNEL_VAR=$REPORT_URL_CHANNEL_ARG; fi;
  if [ ! -z "$DEPLOY_TIMEOUT_ARG" ]; then DEPLOY_TIMEOUT_VAR=$DEPLOY_TIMEOUT_ARG; fi;
}


function check_action()
{
  if [ -z "$DO_ACTION" ];
  then
    echo "no action specified";
    echo "$0 -h for usage";
    exit;
  fi;
}


function process_action()
{
  case $DO_ACTION in
    login)
      login
      exit
      ;;
    login-kube)
      login_kube
      exit
      ;;
    build-docker)
      build_docker;
      ;;
    login-docker)
      login_docker;
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
   report-status)
      report_status;
      ;;
    rollback)
      rollback;
      ;;
    *)
      echo "ERROR: unknown action \"$DO_ACTION\""
      echo "$0 -h for usage";
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
    echo "ERROR: needs account_json, project_id, compute_zone, cluster_name - $0 -h for usage";
  fi;
  exit;
}


function login_kube()
{
  if [ -n "$GOOGLE_ACCOUNT_JSON_VAR" -a -n "$GOOGLE_PROJECT_ID_VAR" -a -n "$GOOGLE_COMPUTE_ZONE_VAR" -a -n "$GOOGLE_CLUSTER_NAME_VAR" ];
  then
    echo "${GOOGLE_ACCOUNT_JSON_VAR}" > account.json;
    gcloud auth activate-service-account --key-file account.json;
    gcloud --quiet config set project ${GOOGLE_PROJECT_ID_VAR};
    gcloud --quiet config set compute/zone ${GOOGLE_COMPUTE_ZONE_VAR};
    gcloud --quiet container clusters get-credentials ${GOOGLE_CLUSTER_NAME_VAR};
  else
    echo "ERROR: needs account_json, project_id, compute_zone, cluster_name - $0 -h for usage";
  fi;
  exit;
}


function login_docker()
{
  if [ -n "$GOOGLE_ACCOUNT_JSON_VAR" ];
  then
    echo "${GOOGLE_ACCOUNT_JSON_VAR}" > account.json;
    gcloud auth activate-service-account --key-file account.json;
  else
    echo "ERROR: needs account_json - $0 -h for usage";
    exit 1;
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
    echo "ERROR: needs project_id, project_name, commit_hash - $0 -h for usage";
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
    echo "ERROR: needs project_id, project_name, commit_hash - $0 -h for usage";

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
    echo "ERROR: needs project_id, project_name, commit_hash - $0 -h for usage";

  fi;
  exit;
}


function rollout_status()
{
  if [ -n "${PROJECT_NAME_VAR}" ];
  then

    interval=1 #1 second
    rollout_status_raw & CPID=$!

    ((t = $DEPLOY_TIMEOUT_VAR ))

      while ((t > 0));
        do
          if [ -n "$(ps -p ${CPID} -o pid=)" ]
            then
              sleep $interval;
              ((t -= $interval))
            else
              exit 0;
          fi
        done

    rollout_status_error $CPID;

  else
    echo "ERROR: needs project_name - $0 -h for usage";
  fi;
  exit;
}


function rollout_status_raw()
{
  kubectl rollout status deployment ${PROJECT_NAME_VAR}
}


function rollout_status_error()
{
  if [ -n "$(ps -p $1 -o pid=)" ]
    then
      rollout_status_error_info;
      echo "INFO: Killing deployment process as is timed out";
      kill -s SIGTERM $1 && kill -0 $1 || exit 0
      sleep 5;
      kill -s SIGKILL $1 2> /dev/null
    else
     exit;
fi;
}


function rollout_status_error_info()
{

ERROR_PODS=$(kubectl get pods --selector=app=${PROJECT_NAME_VAR} -o go-template='{{range $index, $element:= .items}}{{range .status.containerStatuses}}{{if .state.waiting.reason }}{{$element.metadata.name}}:{{ .name }}:{{.state.waiting.reason }}{{"\n"}}{{end}}{{end}}{{end}}');

for item in $ERROR_PODS
 do
   printf "INFO: POD ${item%%:*} is in status ${item##*:}\n";
   tmpc=${item%:*};
   printf "INFO: logs for container ${tmpc#*:}\n";
   kubectl logs ${item%%:*} --container=${tmpc#*:} --tail=150;
   printf "\n";
 done

}


function rollback()
{
  if [ -n "${PROJECT_NAME_VAR}" ];
  then
    kubectl rollout undo deployment/${PROJECT_NAME_VAR}
  else
    echo "ERROR: needs project_name  - $0 -h for usage";
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
    echo "cluster_name: "$GOOGLE_CLUSTER_NAME;
    echo "project_name: "$PROJECT_NAME;
    echo "commit_hash: "$CIRCLE_SHA1;
    echo "action: "$DO_ACTION;


  fi;
}


function report_status()
{
  if [ -n "${PROJECT_NAME_VAR}" -a -n "${REPORT_URL_VAR}" -a -n "${CIRCLE_SHA1_VAR}" -a -n "${REPORT_URL_CHANNEL_VAR}" -a -n"${GOOGLE_CLUSTER_NAME_VAR}" ];
  then
    STATUS_TEXT=$(kubectl rollout status deployment ${PROJECT_NAME_VAR} --watch=false);

    REPORT_COLOR="danger"; #default
    REPORT_FILTER="successfully";
    DEPLOY_STATUS=$(echo $STATUS_TEXT | sed 's/"/*/g' | sed "s/'/*/g" );
    REPOLINK_VAR="";
    MESSAGE_TEXT="From commit: ${CIRCLE_SHA1_VAR}"

    if [ -n "${CIRCLE_PROJECT_USERNAME_VAR}"  -a -n "${CIRCLE_PROJECT_REPONAME_VAR}" ];
      then
        REPOLINK_VAR="https://github.com/${CIRCLE_PROJECT_USERNAME_VAR}/${CIRCLE_PROJECT_REPONAME_VAR}/commit/${CIRCLE_SHA1_VAR}";
        MESSAGE_TEXT="From commit: <${REPOLINK_VAR}|${CIRCLE_SHA1_VAR}>"
    fi

    if [ "$DEPLOY_STATUS" != "${DEPLOY_STATUS%$REPORT_FILTER*}" ];
      then
        REPORT_COLOR="good";
      else
        DEPLOY_STATUS="${DEPLOY_STATUS} - Check CI for details";
    fi

    JSON_REPORT="{\"channel\":\"${REPORT_URL_CHANNEL_VAR}-${GOOGLE_CLUSTER_NAME_VAR}\",
    \"username\":\"${PROJECT_NAME_VAR}\",
     \"attachments\":[
                      {
                        \"fallback\": \"${DEPLOY_STATUS} - ${CIRCLE_BUILD_URL_VAR}\",
                        \"pretext\": \"\",
                        \"title\": \"${DEPLOY_STATUS} - CI build: ${CIRCLE_BUILD_NUM_VAR}\",
                        \"title_link\": \"${CIRCLE_BUILD_URL_VAR}\",
                        \"text\": \"${MESSAGE_TEXT}\",
                        \"color\": \"${REPORT_COLOR}\"
                      }
                  ]}";
    REPORT_ANSWER=`curl -X POST -H 'Content-type: application/json' --data "$JSON_REPORT" "$REPORT_URL_VAR"`;
    exit;
  else
    echo "ERROR: needs project_name, report url, report channel, commit hash, cluster name - $0 -h for usage";
  fi;
  exit;
}


read_args "$@";

read_env_vars;

override_env_vars;

show-var;

check_action;

process_action;
