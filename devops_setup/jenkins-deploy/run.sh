#!/usr/bin/bash

# 字体颜色
RED="\e[31m"
GREEN="\e[32m"
ENDCOLOR="\e[0m"

echo_green(){
  echo -e "${GREEN}${1} ${ENDCOLOR}"
}

echo_red(){
  echo -e "${RED}${1} ${ENDCOLOR}"
}

# 读取Jenkins配置
. ./config

# 校验config文件参数
verify_config(){
    [ -z ${AWS_ACCESS_KEY_ID} ] && { echo_red "AWS_ACCESS_KEY_ID is Required, Please set it"; exit -1; }
    [ -z ${AWS_SECRET_ACCESS_KEY} ] && { echo_red "AWS_SECRET_ACCESS_KEY is Required, Please set it"; exit -1; }
    [ -z ${AWS_DEFAULT_REGION} ] && { echo_red "AWS_DEFAULT_REGION is Required, Please set it"; exit -1; }
    [ -z ${EKS_CLUSTER} ] && { echo_red "EKS_CLUSTER is Required, Please set it"; exit -1; }
    [ -z ${AWS_ACCOUNT_ID} ] && { echo_red "AWS_ACCOUNT_ID is Required, Please set it"; exit -1; }
    [ -z ${s3_bucket_name} ] && { echo_red "s3_bucket_name is Required, Please set it"; exit -1; }
    [ -z ${file_system_id} ] && { echo_red "file_system_id is Required, Please set it"; exit -1; }
    [ -z ${busybox_image} ] && { echo_red "busybox_image is Required, Please set it"; exit -1; }
    [ -z ${jenkins_image} ] && { echo_red "jenkins_image is Required, Please set it"; exit -1; }
    [ -z ${jenkins_plugins_url} ] && { echo_red "jenkins_plugins_url is Required, Please set it"; exit -1; }
    [ -z ${namespace} ] && { echo_red "namespace is Required, Please set it"; exit -1; }
    [ -z ${jenkins_slave_namespace} ] && { echo_red "jenkins_slave_namespace is Required, Please set it"; exit -1; }
    [ -z ${requests_cpu} ] && { echo_red "requests_cpu is Required, Please set it"; exit -1; }
    [ -z ${requests_mem} ] && { echo_red "requests_mem is Required, Please set it"; exit -1; }
    [ -z ${limits_cpu} ] && { echo_red "limits_cpu is Required, Please set it"; exit -1; }
    [ -z ${limits_mem} ] && { echo_red "limits_mem is Required, Please set it"; exit -1; }
    [ -z "${jenkins_javaopts}" ] && { echo_red "jenkins_javaopts is Required, Please set it"; exit -1; }
}


create_jenkins_pv(){
  echo """
  apiVersion: v1
  kind: PersistentVolume
  metadata:
    name: jenkins-pv
    labels:
      pv: jenkins-pv
  spec:
    capacity:
      storage: 5Ti
    volumeMode: Filesystem
    accessModes:
      - ReadWriteMany
    storageClassName: ""
    persistentVolumeReclaimPolicy: Retain
    csi:
      driver: efs.csi.aws.com
      volumeHandle: ${file_system_id}:/jenkins
  """ | kubectl apply -f -
}

create_jenkins_pvc(){
  # 创建jenkins pvc
  echo '
  apiVersion: v1
  kind: PersistentVolumeClaim
  metadata:
    name: jenkins-pvc
    namespace: devops
  spec:
    accessModes:
      - ReadWriteMany
    storageClassName: ""
    resources:
      requests:
        storage: 5Ti
    selector:
      matchLabels:
        pv: jenkins-pv
  ' | kubectl apply -f -
  jenkins_pvc_status=$(kubectl -n ${namespace} get pvc jenkins-pvc | grep Bound | wc -l)
  [ ${jenkins_pvc_status} == 1 ] && echo "jenkins pv pvc创建成功" || { echo_red "jenkins pv pvc创建失败"; exit -1; }
}

create_jenkins_slave_pv(){
  echo """
  apiVersion: v1
  kind: PersistentVolume
  metadata:
    name: jenkins-slave-pv
    labels:
      pv: jenkins-slave-pv
  spec:
    capacity:
      storage: 5Ti
    volumeMode: Filesystem
    accessModes:
      - ReadWriteMany
    storageClassName: ""
    persistentVolumeReclaimPolicy: Retain
    csi:
      driver: efs.csi.aws.com
      volumeHandle: ${file_system_id}:/jenkins-slave
  """ | kubectl apply -f -
}

create_jenkins_slave_pvc(){
  echo """
  apiVersion: v1
  kind: PersistentVolumeClaim
  metadata:
    name: jenkins-slave-pvc
    namespace: ${jenkins_slave_namespace}
  spec:
    accessModes:
      - ReadWriteMany
    storageClassName: ''
    resources:
      requests:
        storage: 5Ti
    selector:
      matchLabels:
        pv: jenkins-slave-pv
  """ | kubectl apply -f -
}

create_jenkins_slave_role(){
  echo '''
  kind: ClusterRole
  apiVersion: rbac.authorization.k8s.io/v1beta1
  metadata:
    name: jenkins-slave-role
  rules:
    - apiGroups: ["extensions", "apps"]
      resources: ["deployments"]
      verbs: ["create", "delete", "get", "list", "watch", "patch", "update"]
    - apiGroups: [""]
      resources: ["services"]
      verbs: ["create", "delete", "get", "list", "watch", "patch", "update"]
    - apiGroups: [""]
      resources: ["pods"]
      verbs: ["create","delete","get","list","patch","update","watch"]
    - apiGroups: [""]
      resources: ["pods/exec"]
      verbs: ["create","delete","get","list","patch","update","watch"]
    - apiGroups: [""]
      resources: ["pods/log"]
      verbs: ["get","list","watch"]
    - apiGroups: [""]
      resources: ["secrets"]
      verbs: ["get"]
    - apiGroups: [""]
      resources: ["events"]
      verbs: ["get","list","watch"]
  ''' | kubectl apply -f -
}

create_jenkins_slave_rolebinding(){
  echo """
  apiVersion: rbac.authorization.k8s.io/v1beta1
  kind: ClusterRoleBinding
  metadata:
    name: jenkins-slave-rolebinding
    namespace: ${namespace}
  roleRef:
    apiGroup: rbac.authorization.k8s.io
    kind: ClusterRole
    name: jenkins-slave-role
  subjects:
    - kind: ServiceAccount
      name: jenkins
      namespace: ${namespace}
  """ | kubectl create -f -
}

render_jcasc_yaml(){
# 渲染jcasc.yaml配置
  sed -e "s/GITLAB_HTTP_PASSWORD/${gitlab_http_password}/g" \
      -e "s/GITLAB_API_TOKEN/${gitlab_api_token}/g" \
      -e "s/AWS_ACCESS_KEY/${aws_access_key}/g" \
      -e "s/AWS_SECRET_KEY/${aws_secret_key}/g" \
      -e "s/SONARQUBE_API_TOKEN/${sonarqube_api_token}/g" \
      -e "s/JENKINS_TUNNEL/${jenkins_tunnel}/g" \
      -e "s|JENKINS_URL|${jenkins_url}|g" \
      -e "s/GITLAB_FQDN_VAR/${gitlab_fqdn}/g" \
      -e "s/JENKINS_FQDN_VAR/${jenkins_fqdn}/g" \
      -e "s/SONARQUBE_FQDN_VAR/${sonarqube_fqdn}/g" jcasc.yaml.template
      > jcasc.yaml
}

# 校验config配置
verify_config

# 创建namespace
echo_green "step1. 创建namespace"
kubectl create ns ${namespace} || { echo "${namespace}已存在，不需创建"; }
kubectl create ns ${jenkins_slave_namespace} || { echo "${jenkins_slave_namespace}已存在，不需创建"; }

# 创建Jenkins pv pvc
echo_green "step2. 创建jenkins-pv、jenkins-pvc"
[ $(kubectl get pv jenkins-pv 2>/dev/null | wc -l ) == 0 ] && { echo "创建jenkins-pv"; create_jenkins_pv; } || { echo "jenkins-pv已存在，不需创建"; }
[ $(kubectl -n ${namespace} get pvc jenkins-pvc 2>/dev/null | wc -l ) == 0 ] && { echo "创建jenkins-pvc"; create_jenkins_pvc; } || { echo "命名空间${namespace}下jekins-pvc已存在，不需创建"; }

echo_green "step3. 创建jenkins-slave-pv、jenkins-slave-pvc、jenkins-slave-role、jenkins-slave-rolebinding"
[ $(kubectl get pv jenkins-slave-pv 2>/dev/null | wc -l ) == 0 ] && { echo "创建jenkins-slave-pv"; create_jenkins_slave_pv; } || { echo "jenkins-slave-pv已存在，不需创建"; }
[ $(kubectl -n ${jenkins_slave_namespace} get pvc jenkins-slave-pvc 2>/dev/null | wc -l ) == 0 ] && { echo "创建jenkins-slave-pvc"; create_jenkins_slave_pvc; } || { echo "命名空间${jenkins_slave_namespace}下jekins-slave-pvc已存在，不需创建"; }
[ $(kubectl -n ${jenkins_slave_namespace} get clusterrole jenkins-slave-role 2>/dev/null | wc -l ) == 0 ] && { echo "创建jenkins-slave-role"; create_jenkins_slave_role; } || { echo "命名空间${jenkins_slave_namespace}下jenkins-slave-role已存在，不需创建"; }
[ $(kubectl -n ${jenkins_slave_namespace} get clusterrolebindings jenkins-slave-rolebinding 2>/dev/null | wc -l ) == 0 ] && { echo "创建jenkins-slave-rolebinding"; create_jenkins_slave_rolebinding; } || { echo "命名空间${namespace}下jenkins-slave-rolebinding已存在，不需创建"; }


# 生成jcasc.yaml
echo_green "step4. 创建jcasc.yaml配置文件"
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
    -e "s|JENKINS_PLUGINS_URL|${jenkins_plugins_url}|g" \
    -e "s|K8S_DEFAULT_CONFIG_BASE64|${k8s_default_config_base64}|g" \
    -e "s|SONARQUBE_FQDN_VAR|${sonarqube_fqdn}|g" jcasc.yaml.template \
    > jcasc.yaml

# 使用helm搭建Jenkins
echo_green "step5. helm部署Jenkins"
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
--set controller.overwritePluginsFromImage=false \
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
echo_green "step6. 检查jenkins状态"
kubectl -n ${namespace} rollout status statefulset jenkins --timeout 10m

[ $? == 0 ] && { echo_green "jenkins部署成功"; } || { echo_red "jenkins部署失败"; }

