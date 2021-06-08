#!/usr/bin/bash
SCRIPT_BASEDIR=$(dirname "$0")

cd ${SCRIPT_BASEDIR}
SCRIPT_BASEDIR="$PWD"
PROJECT_BASEDIR=$(dirname "${SCRIPT_BASEDIR}")

# include lib/*
source ${PROJECT_BASEDIR}/lib/*

# include config
if [ 0 == $(ps -p $PPID o cmd | grep install.sh | wc -l) ];then
  [ -f "${SCRIPT_BASEDIR}/config" ] && { source ${SCRIPT_BASEDIR}/config; } || { echo_red "ERROR: ${SCRIPT_BASEDIR}/config not exist"; exit 110; }
  [ -f "${PROJECT_BASEDIR}/sonarqube-deploy/config" ] && { source ${PROJECT_BASEDIR}/sonarqube-deploy/config; } || { echo_red "ERROR: ${PROJECT_BASEDIR}/sonarqube-deploy/config not exist"; exit 110; }
  [ -f "${PROJECT_BASEDIR}/jenkins-deploy/config" ] && { source ${PROJECT_BASEDIR}/jenkins-deploy/config; } || { echo_red "ERROR: ${PROJECT_BASEDIR}/jenkins-deploy/config not exist"; exit 110; }
else
  [ -f "${PROJECT_BASEDIR}/config" ] && { source ${PROJECT_BASEDIR}/config; } || { echo_red "ERROR: ${PROJECT_BASEDIR}/config not exist"; exit 110; }
fi

echo_green "step1. Setup sonarqube 9000 port forward to 0.0.0.0 8885"
# 配置gitlab端口转发
kubectl -n ${namespace} port-forward --address 0.0.0.0 svc/sonarqube-sonarqube 8885:9000 >/dev/null 2>&1 &
sleep 10

echo_green "step2. Create service user, api token etc."
# 创建service用户
curl -X POST -u admin:${sonarqube_admin_password} -d "login=${service_user}&name=${service_user}&email=${service_user}@nomail.com&password=${service_password}" "http://127.0.0.1:8885/api/users/create"

# 创建service用户api token
sonarqube_api_token=$(curl -s -X POST -u admin:${sonarqube_admin_password} -d "login=${service_user}&name=sonarqube-api-token" "http://127.0.0.1:8885/api/user_tokens/generate" | ${PROJECT_BASEDIR}/tools/jq -r ".token")

echo_green ${sonarqube_api_token} > ${SCRIPT_BASEDIR}/sonarqube-api-token

# 创建sonarqube回调jenkins webhook
curl -u admin:${sonarqube_admin_password} -X POST -d "name=jenkins&url=http://${jenkins_fqdn}/sonarqube-webhook/" "http://127.0.0.1:8885/api/webhooks/create"

netstat -tnlup | grep 8885 | awk '{print $NF}' | awk -F'/' '{print $1}' | xargs kill -9
