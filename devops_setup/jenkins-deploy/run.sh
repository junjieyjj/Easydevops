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
  ${jenkins_image} \
  ${requests_cpu} \
  ${requests_mem} \
  ${limits_cpu} \
  ${limits_mem} \
  ${jenkins_javaopts} \
  ${gitlab_ssh_key_base64} \
  ${gitlab_http_password} \
  ${gitlab_api_token} \
  ${sonarqube_api_token} \
  ${gitlab_fqdn} \
  ${jenkins_fqdn} \
  ${sonarqube_fqdn} \
  ${jenkins_tunnel} \
  ${jenkins_url} \
  ${jenkins_slave_namespace} \
  ${aws_access_key} \
  ${aws_secret_key} 

# create jenkins pv pvc
logger_info "step1. Create jenkins-pv、jenkins-pvc"
[ $(kubectl get pv jenkins-pv 2>/dev/null | wc -l ) == 0 ] && { logger_info "create jenkins-pv"; create_efs_pv ${file_system_id} jenkins-pv jenkins; } || { logger_info "jenkins-pv is already existed, not create"; }
check_pv_status jenkins-pv

[ $(kubectl -n ${namespace} get pvc jenkins-pvc 2>/dev/null | wc -l ) == 0 ] && { logger_info "create jenkins-pvc"; create_efs_pvc ${namespace} jenkins-pvc jenkins-pv; } || { logger_info "namespace:${namespace} jenkins-pvc is already existed，not create"; }
check_pvc_status ${namespace} jenkins-pvc

# create jenkins slave pv pvc
logger_info "step2. Create jenkins-slave-pv、jenkins-slave-pvc"
[ $(kubectl get pv jenkins-slave-pv 2>/dev/null | wc -l ) == 0 ] && { logger_info "create jenkins-slave-pv"; create_efs_pv ${file_system_id} jenkins-slave-pv jenkins-slave; } || { logger_info "jenkins-slave-pv is already existed, not create"; }
check_pv_status jenkins-slave-pv

[ $(kubectl -n ${jenkins_slave_namespace} get pvc jenkins-slave-pvc 2>/dev/null | wc -l ) == 0 ] && { logger_info "create jenkins-slave-pvc"; create_efs_pvc ${jenkins_slave_namespace} jenkins-slave-pvc jenkins-slave-pv; } || { logger_info "namespace:${jenkins_slave_namespace} jenkins-slave-pvc is already existed，not create"; }
check_pvc_status ${jenkins_slave_namespace} jenkins-slave-pvc

echo_green "step3. Create jenkins-slave-role、jenkins-slave-rolebinding"
[ $(kubectl -n ${jenkins_slave_namespace} get clusterrole jenkins-slave-role 2>/dev/null | wc -l ) == 0 ] && { logger_info "create jenkins-slave-role"; create_cluster_role jenkins-slave-role; } || { logger_info "namespace: ${jenkins_slave_namespace} jenkins-slave-role is already existed，not create"; }
check_cluster_role jenkins-slave-role

[ $(kubectl -n ${jenkins_slave_namespace} get clusterrolebindings jenkins-slave-rolebinding 2>/dev/null | wc -l ) == 0 ] && { logger_info "create jenkins-slave-rolebinding"; create_cluster_rolebinding jenkins-slave-rolebinding jenkins-slave-role jenkins ${namespace}; } || { logger_info "namespace: ${namespace} jenkins-slave-rolebinding is already existed，not create"; }
check_cluster_rolebinding ${namespace} jenkins-slave-rolebinding

# 生成jcasc.yaml
logger_info "step4. 创建jcasc.yaml配置文件"
# render_jcasc_yaml()
sed -e "s|GITLAB_SSH_KEY_BASE64|${gitlab_ssh_key_base64}|g" \
    -e "s|GITLAB_HTTP_PASSWORD|${gitlab_http_password}|g" \
    -e "s|GITLAB_API_TOKEN|${gitlab_api_token}|g" \
    -e "s|AWS_ACCESS_KEY|${aws_access_key}|g" \
    -e "s|AWS_SECRET_KEY|${aws_secret_key}|g" \
    -e "s|SONARQUBE_API_TOKEN|${sonarqube_api_token}|g" \
    -e "s|JENKINS_TUNNEL|${jenkins_tunnel}|g" \
    -e "s|JENKINS_URL|${jenkins_url}|g" \
    -e "s|GITLAB_FQDN_VAR|${gitlab_fqdn}|g" \
    -e "s|JENKINS_FQDN_VAR|${jenkins_fqdn}|g" \
    -e "s|K8S_DEFAULT_CONFIG_BASE64|${k8s_default_config_base64}|g" \
    -e "s|SONARQUBE_FQDN_VAR|${sonarqube_fqdn}|g" jcasc.yaml.template \
    > jcasc.yaml

# 使用helm搭建Jenkins
logger_info "step5. Helm deploy Jenkins"
helm upgrade jenkins ./jenkins \
--version 3.3.9 \
--namespace ${namespace} \
--create-namespace \
--install \
--debug \
--set controller.image=`echo ${jenkins_image} | awk -F: '{print $1}'` \
--set controller.tag=`echo ${jenkins_image} | awk -F: '{print $2}'` \
--set controller.updateStrategy.type=RollingUpdate \
--set controller.adminSecret=false \
--set controller.adminUser=admin \
--set controller.adminPassword=admin \
--set controller.installPlugins=false \
--set controller.overwritePlugins=false \
--set controller.overwritePluginsFromImage=true \
--set controller.initializeOnce=true \
--set persistence.enabled=true \
--set controller.serviceType=LoadBalancer \
--set-string controller.runAsUser=0 \
--set-string controller.fsGroup=0 \
--set-string controller.resources.requests.cpu=${requests_cpu} \
--set-string controller.resources.requests.memory=${requests_mem} \
--set-string controller.resources.limits.cpu=${limits_cpu} \
--set-string controller.resources.limits.memory=${limits_mem} \
--set-string controller.javaOpts="${jenkins_javaopts}" \
--set controller.JCasC.defaultConfig=false \
--set controller.sidecars.configAutoReload.enabled=false \
--set persistence.existingClaim=jenkins-pvc \
--set agent.enabled=true \
-f ./jcasc.yaml --dry-run > ${LOG_DIR}/helm-jenkins.yaml

helm upgrade jenkins ./jenkins \
--version 3.3.9 \
--namespace ${namespace} \
--create-namespace \
--install \
--set controller.image=`echo ${jenkins_image} | awk -F: '{print $1}'` \
--set controller.tag=`echo ${jenkins_image} | awk -F: '{print $2}'` \
--set controller.updateStrategy.type=RollingUpdate \
--set controller.adminSecret=false \
--set controller.adminUser=admin \
--set controller.adminPassword=admin \
--set controller.installPlugins=false \
--set controller.overwritePlugins=false \
--set controller.overwritePluginsFromImage=true \
--set controller.initializeOnce=true \
--set persistence.enabled=true \
--set controller.serviceType=LoadBalancer \
--set-string controller.runAsUser=0 \
--set-string controller.fsGroup=0 \
--set-string controller.resources.requests.cpu=${requests_cpu} \
--set-string controller.resources.requests.memory=${requests_mem} \
--set-string controller.resources.limits.cpu=${limits_cpu} \
--set-string controller.resources.limits.memory=${limits_mem} \
--set-string controller.javaOpts="${jenkins_javaopts}" \
--set controller.JCasC.defaultConfig=false \
--set controller.sidecars.configAutoReload.enabled=false \
--set persistence.existingClaim=jenkins-pvc \
--set agent.enabled=true \
-f ./jcasc.yaml 

# 检查jenkins statefulset启动状态
echo_green "step6. Check jenkins status"
kubectl -n ${namespace} rollout status statefulset jenkins --timeout 10m

[ $? == 0 ] && { logger_info "deploy jenkins successful"; } || { logger_error "deploy jenkins failed"; }

