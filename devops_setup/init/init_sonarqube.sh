#!/usr/bin/bash
SCRIPT_BASEDIR=$(dirname "$0")

cd ${SCRIPT_BASEDIR}
SCRIPT_BASEDIR="$PWD"
PROJECT_BASEDIR=$(dirname "${SCRIPT_BASEDIR}")

# 加载配置文件
source ${SCRIPT_BASEDIR}/config
source ${PROJECT_BASEDIR}/sonarqube-deploy/config
source ${PROJECT_BASEDIR}/jenkins-deploy/config

echo "step1. Setup sonarqube 9000 port forward to 0.0.0.0 8885"
# 配置gitlab端口转发
kubectl -n ${namespace} port-forward --address 0.0.0.0 svc/sonarqube-sonarqube 8885:9000 >/dev/null 2>&1 &

echo "step2. Create service user, api token etc."
# 创建service用户
curl -X POST -u admin:${sonarqube_admin_password} -d "login=${service_user}&name=${service_user}&email=${service_user}@nomail.com&password=${service_password}" "http://127.0.0.1:8885/api/users/create"

# 创建service用户api token
sonarqube_api_token=$(curl -s -X POST -u admin:${sonarqube_admin_password} -d "login=${service_user}&name=sonarqube-api-token" "http://127.0.0.1:8885/api/user_tokens/generate" | ${PROJECT_BASEDIR}/tools/jq -r ".token")

echo ${sonarqube_api_token} > ${SCRIPT_BASEDIR}/sonarqube-api-token

# 创建sonarqube回调jenkins webhook
curl -u admin:${sonarqube_admin_password} -X POST -d "name=jenkins&url=http://${jenkins_fqdn}/sonarqube-webhook/" "http://127.0.0.1:8885/api/webhooks/create"

netstat -tnlup | grep 8885 | awk '{print $NF}' | awk -F'/' '{print $1}' | xargs kill -9
