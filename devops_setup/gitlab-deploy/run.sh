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
else
  [ -f "${PROJECT_BASEDIR}/config" ] && { source ${PROJECT_BASEDIR}/config; } || { echo_red "ERROR: ${PROJECT_BASEDIR}/config not exist"; exit 110; }
fi

# check aws config
check_aws_env

# check config params
verify_params_null \
  ${file_system_id} \
  ${namespace} \
  ${gitlab_root_password} \
  ${gitlab_external_url} \
  ${gitlab_image} \
  ${requests_cpu} \
  ${requests_mem} \
  ${limits_cpu} \
  ${limits_mem} \
  ${gitlab_postgresql_db_host} \
  ${gitlab_postgresql_db_database} \
  ${gitlab_postgresql_db_username} \
  ${gitlab_postgresql_db_password} \
  ${gitlab_postgresql_db_port} \
  ${gitlab_redis_host} \
  ${gitlab_redis_port}

# create pv pvc
logger_info "step1. create gitlab-pv、gitlab-pvc"
[ $(kubectl get pv gitlab-pv 2>/dev/null | wc -l ) == 0 ] && { logger_info "create gitlab-pv"; create_efs_pv ${file_system_id} gitlab-pv gitlab; } || { logger_info "gitlab-pv is already existed, not create"; }
check_pv_status gitlab-pv

[ $(kubectl -n ${namespace} get pvc gitlab-pvc 2>/dev/null | wc -l ) == 0 ] && { logger_info "create gitlab-pvc"; create_efs_pvc ${namespace} gitlab-pvc gitlab-pv; } || { logger_info "namespace:${namespace} gitlab-pvc is already existed，not create"; }
check_pvc_status ${namespace} gitlab-pvc

# 渲染gitlab.yaml配置
sed -e "s|GITLAB_EXTERNAL_URL|${gitlab_external_url}|" \
    -e "s/GITLAB_POSTGRESQL_DB_DATABASE/${gitlab_postgresql_db_database}/" \
    -e "s/GITLAB_POSTGRESQL_DB_USERNAME/${gitlab_postgresql_db_username}/" \
    -e "s/GITLAB_POSTGRESQL_DB_PASSWORD/${gitlab_postgresql_db_password}/" \
    -e "s/GITLAB_POSTGRESQL_DB_HOST/${gitlab_postgresql_db_host}/" \
    -e "s/GITLAB_POSTGRESQL_DB_PORT/${gitlab_postgresql_db_port}/" \
    -e "s/GITLAB_REDIS_HOST/${gitlab_redis_host}/" \
    -e "s/GITLAB_REDIS_PORT/${gitlab_redis_port}/" gitlab.yaml.template \
    > gitlab.yaml

# 使用helm搭建Gitlab
logger_info "step2. helm deploy Gitlab"
helm upgrade gitlab ./gitlab-ce \
--namespace ${namespace}  \
--version 1.0.0 \
--create-namespace \
--install \
--debug \
--set image=${gitlab_image} \
--set externalUrl=${gitlab_external_url} \
--set gitlabRootPassword=${gitlab_root_password} \
--set service.type=ClusterIP \
--set service.ssh.port=22 \
--set service.http.port=80 \
--set service.https.port=443 \
--set ingress.enabled=false \
--set-string resources.requests.cpu=${requests_cpu} \
--set-string resources.requests.memory=${requests_mem} \
--set-string resources.limits.cpu=${limits_cpu} \
--set-string resources.limits.memory=${limits_mem} \
--set persistence.enabled=true \
--set persistence.pvcName=gitlab-pvc \
--set persistence.mountInfo[0].name=gitlab-pvc,\
persistence.mountInfo[0].mountPath=/etc/gitlab,\
persistence.mountInfo[0].subPath=config \
--set persistence.mountInfo[1].name=gitlab-pvc,\
persistence.mountInfo[1].mountPath=/var/log/gitlab,\
persistence.mountInfo[1].subPath=logs \
--set persistence.mountInfo[2].name=gitlab-pvc,\
persistence.mountInfo[2].mountPath=/var/opt/gitlab,\
persistence.mountInfo[2].subPath=data \
-f gitlab.yaml --dry-run > ${LOG_DIR}/helm-gitlab.yaml

helm upgrade gitlab ./gitlab-ce \
--namespace ${namespace}  \
--version 1.0.0 \
--create-namespace \
--install \
--set image=${gitlab_image} \
--set externalUrl=${gitlab_external_url} \
--set gitlabRootPassword=${gitlab_root_password} \
--set service.type=ClusterIP \
--set service.ssh.port=22 \
--set service.http.port=80 \
--set service.https.port=443 \
--set ingress.enabled=false \
--set-string resources.requests.cpu=${requests_cpu} \
--set-string resources.requests.memory=${requests_mem} \
--set-string resources.limits.cpu=${limits_cpu} \
--set-string resources.limits.memory=${limits_mem} \
--set persistence.enabled=true \
--set persistence.pvcName=gitlab-pvc \
--set persistence.mountInfo[0].name=gitlab-pvc,\
persistence.mountInfo[0].mountPath=/etc/gitlab,\
persistence.mountInfo[0].subPath=config \
--set persistence.mountInfo[1].name=gitlab-pvc,\
persistence.mountInfo[1].mountPath=/var/log/gitlab,\
persistence.mountInfo[1].subPath=logs \
--set persistence.mountInfo[2].name=gitlab-pvc,\
persistence.mountInfo[2].mountPath=/var/opt/gitlab,\
persistence.mountInfo[2].subPath=data \
-f gitlab.yaml

rm -f gitlab.yaml

# 检查jenkins statefulset启动状态
logger_info "step3. check gitlab status"
kubectl -n ${namespace} rollout status statefulset gitlab --timeout 5m

[ $? == 0 ] && { logger_info "gitlab deploy successful"; } || { logger_error "gitlab deploy failed"; exit 110; }


