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
  ${sonarqube_admin_password} \
  ${busybox_image} \
  ${sonarqube_image} \
  ${requests_cpu} \
  ${requests_mem} \
  ${limits_cpu} \
  ${limits_mem} \
  ${sonarqube_postgresql_db_host} \
  ${sonarqube_postgresql_db_database} \
  ${sonarqube_postgresql_db_username} \
  ${sonarqube_postgresql_db_password} \
  ${sonarqube_postgresql_db_port} \
  ${sonarqube_plugins_image} \
  ${sonarqube_javaopts}

# create pv pvc
logger_info "step1. Create sonarqube-pv、sonarqube-pvc"
[ $(kubectl get pv sonarqube-pv 2>/dev/null | wc -l ) == 0 ] && { logger_info "create sonarqube-pv"; create_efs_pv ${file_system_id} sonarqube-pv sonarqube; } || { logger_info "sonarqube-pv is already existed, not create"; }
check_pv_status sonarqube-pv

[ $(kubectl -n ${namespace} get pvc sonarqube-pvc 2>/dev/null | wc -l ) == 0 ] && { logger_info "create sonarqube-pvc"; create_efs_pvc ${file_system_id} ${namespace} sonarqube-pvc sonarqube-pv; } || { logger_info "namespace:${namespace} sonarqube-pvc is already existed，not create"; }
check_pvc_status ${namespace} sonarqube-pvc

# 使用helm搭建Jenkins
sed -e "s|SONARQUBE_PLUGINS_IMAGE|${sonarqube_plugins_image}|g" \
sonarqube.yaml.template > sonarqube.yaml

logger_info "step2. Helm deploy sonarqube"
helm upgrade sonarqube ./sonarqube \
--version 3.5.4 \
--namespace devops \
--create-namespace \
--install \
--debug \
--set image.repository=`echo ${sonarqube_image} | awk -F: '{print $1}'` \
--set image.tag=`echo ${sonarqube_image} | awk -F: '{print $2}'` \
--set securityContext.fsGroup=0 \
--set containerSecurityContext.runAsUser=0 \
--set service.type=ClusterIP \
--set deploymentStrategy.type=Recreate \
--set persistence.enabled=true \
--set persistence.existingClaim=sonarqube-pvc \
--set postgresql.enabled=false  \
--set postgresql.postgresqlUsername="${sonarqube_postgresql_db_username}" \
--set postgresql.postgresqlPassword="${sonarqube_postgresql_db_password}" \
--set jdbcUrlOverride="jdbc:postgresql://${sonarqube_postgresql_db_host}:${sonarqube_postgresql_db_port}/${sonarqube_postgresql_db_database}" \
--set account.adminPassword=${sonarqube_admin_password} \
--set account.currentAdminPassword=admin \
--set curlContainerImage=${curl_image} \
--set initContainers.image=${busybox_image} \
--set initSysctl.securityContext.privileged=true \
--set initSysctl.image=${busybox_image} \
--set-string resources.requests.cpu=${requests_cpu} \
--set-string resources.requests.memory=${requests_mem} \
--set-string resources.limits.cpu=${limits_cpu} \
--set-string resources.limits.memory=${limits_mem} \
--set-string jvmOpts="${sonarqube_javaopts}" \
-f sonarqube.yaml --dry-run > ${LOG_DIR}/helm-sonarqube.yaml

helm upgrade sonarqube ./sonarqube \
--version 3.5.4 \
--namespace devops \
--create-namespace \
--install \
--set image.repository=`echo ${sonarqube_image} | awk -F: '{print $1}'` \
--set image.tag=`echo ${sonarqube_image} | awk -F: '{print $2}'` \
--set securityContext.fsGroup=0 \
--set containerSecurityContext.runAsUser=0 \
--set service.type=ClusterIP \
--set deploymentStrategy.type=Recreate \
--set persistence.enabled=true \
--set persistence.existingClaim=sonarqube-pvc \
--set postgresql.enabled=false  \
--set postgresql.postgresqlUsername="${sonarqube_postgresql_db_username}" \
--set postgresql.postgresqlPassword="${sonarqube_postgresql_db_password}" \
--set jdbcUrlOverride="jdbc:postgresql://${sonarqube_postgresql_db_host}:${sonarqube_postgresql_db_port}/${sonarqube_postgresql_db_database}" \
--set account.adminPassword=${sonarqube_admin_password} \
--set account.currentAdminPassword=admin \
--set curlContainerImage=${curl_image} \
--set initContainers.image=${busybox_image} \
--set initSysctl.securityContext.privileged=true \
--set initSysctl.image=${busybox_image} \
--set-string resources.requests.cpu=${requests_cpu} \
--set-string resources.requests.memory=${requests_mem} \
--set-string resources.limits.cpu=${limits_cpu} \
--set-string resources.limits.memory=${limits_mem} \
--set-string jvmOpts="${sonarqube_javaopts}" \
-f sonarqube.yaml

rm -f sonarqube.yaml

# 检查sonarqube deployment启动状态
logger_info "step3. Check sonarqube status"
kubectl -n ${namespace} rollout status deployment sonarqube-sonarqube --timeout 10m

[ $? == 0 ] && { logger_info "sonarqube deploy successful"; } || { logger_error "sonarqube deploy failed"; }

