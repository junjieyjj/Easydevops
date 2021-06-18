#!/usr/bin/bash
SCRIPT_BASEDIR=$(dirname "$0")

cd ${SCRIPT_BASEDIR}
SCRIPT_BASEDIR="$PWD"
PROJECT_BASEDIR=$(dirname "${SCRIPT_BASEDIR}")
LOG_DIR=${PROJECT_BASEDIR}/logs

# include lib
source ${PROJECT_BASEDIR}/lib/utils/logger.sh
source ${PROJECT_BASEDIR}/lib/utils/utils.sh
source ${PROJECT_BASEDIR}/lib/utils/verify.sh
source ${PROJECT_BASEDIR}/lib/k8s/utils.sh

# include config
if [ 0 == $(ps -p $PPID o cmd | grep install.sh | wc -l) ];then
  [ -f "${SCRIPT_BASEDIR}/config" ] && { source ${SCRIPT_BASEDIR}/config; } || { echo_red "ERROR: ${SCRIPT_BASEDIR}/config not exist"; exit 110; }
  [ -f "${PROJECT_BASEDIR}/sonarqube-deploy/config" ] && { source ${PROJECT_BASEDIR}/sonarqube-deploy/config; } || { echo_red "ERROR: ${PROJECT_BASEDIR}/sonarqube-deploy/config not exist"; exit 110; }
  [ -f "${PROJECT_BASEDIR}/jenkins-deploy/config" ] && { source ${PROJECT_BASEDIR}/jenkins-deploy/config; } || { echo_red "ERROR: ${PROJECT_BASEDIR}/jenkins-deploy/config not exist"; exit 110; }
else
  [ -f "${PROJECT_BASEDIR}/config" ] && { source ${PROJECT_BASEDIR}/config; } || { echo_red "ERROR: ${PROJECT_BASEDIR}/config not exist"; exit 110; }
fi

logger_info "step1. Setup sonarqube 9000 port forward to 0.0.0.0 8885"
# 配置gitlab端口转发
kubectl -n ${namespace} port-forward --address 0.0.0.0 svc/sonarqube-sonarqube 8885:9000 >/dev/null 2>&1 &
check_local_port_listen 8885

logger_info "step2. Create service user, api token etc."
# 创建service用户
logger_info "======================================"
logger_info "1. create service user"
logger_debug "call api command: curl -s -X POST -u admin:********* -d \"login=${service_user}&name=${service_user}&email=${service_user}@nomail.com&password=************\" \"http://127.0.0.1:8885/api/users/create\""
logger_debug $(curl -s -X POST -u admin:${sonarqube_admin_password} -d "login=${service_user}&name=${service_user}&email=${service_user}@nomail.com&password=${service_password}" "http://127.0.0.1:8885/api/users/create")

# 创建service用户api token
logger_info "======================================"
logger_info "2. create api token for service user"
logger_debug "call api command: curl -s -X POST -u admin:${sonarqube_admin_password} -d \"login=${service_user}&name=sonarqube-api-token\" \"http://127.0.0.1:8885/api/user_tokens/generate\""
sonarqube_api_token=$(curl -s -X POST -u admin:${sonarqube_admin_password} -d "login=${service_user}&name=sonarqube-api-token" "http://127.0.0.1:8885/api/user_tokens/generate" | ${PROJECT_BASEDIR}/tools/jq -r ".token")
logger_debug "sonarqube-api-token: ${sonarqube_api_token}"

echo ${sonarqube_api_token} > ${SCRIPT_BASEDIR}/sonarqube-api-token

# 创建sonarqube回调jenkins webhook
logger_info "======================================"
logger_info "3. create api token for service user"
logger_debug "call api command: curl -u admin:************* -X POST -d \"name=jenkins&url=http://${jenkins_fqdn}/sonarqube-webhook/\" \"http://127.0.0.1:8885/api/webhooks/create\""
logger_debug $(curl -s -u admin:${sonarqube_admin_password} -X POST -d "name=jenkins&url=http://${jenkins_fqdn}/sonarqube-webhook/" "http://127.0.0.1:8885/api/webhooks/create")

netstat -tnlup | grep 8885 | awk '{print $NF}' | awk -F'/' '{print $1}' | xargs kill -9
