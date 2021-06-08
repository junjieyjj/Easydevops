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
else
  [ -f "${PROJECT_BASEDIR}/config" ] && { source ${PROJECT_BASEDIR}/config; } || { echo_red "ERROR: ${PROJECT_BASEDIR}/config not exist"; exit 110; }
fi

# 校验config文件参数
verify_config(){
    [ -z ${AWS_ACCESS_KEY_ID} ] && { echo_red "AWS_ACCESS_KEY_ID is Required, Please set it"; exit -1; }
    [ -z ${AWS_SECRET_ACCESS_KEY} ] && { echo_red "AWS_SECRET_ACCESS_KEY is Required, Please set it"; exit -1; }
    [ -z ${AWS_DEFAULT_REGION} ] && { echo_red "AWS_DEFAULT_REGION is Required, Please set it"; exit -1; }
    [ -z ${EKS_CLUSTER} ] && { echo_red "EKS_CLUSTER is Required, Please set it"; exit -1; }
    [ -z ${AWS_ACCOUNT_ID} ] && { echo_red "AWS_ACCOUNT_ID is Required, Please set it"; exit -1; }
    [ -z ${file_system_id} ] && { echo_red "file_system_id is Required, Please set it"; exit -1; }
    [ -z ${sonarqube_admin_password} ] && { echo_red "sonarqube_admin_password is Required, Please set it"; exit -1; }
    [ -z ${busybox_image} ] && { echo_red "busybox_image is Required, Please set it"; exit -1; }
    [ -z ${sonarqube_image} ] && { echo_red "sonarqube_image is Required, Please set it"; exit -1; }
    [ -z ${namespace} ] && { echo_red "namespace is Required, Please set it"; exit -1; }
    [ -z ${requests_cpu} ] && { echo_red "requests_cpu is Required, Please set it"; exit -1; }
    [ -z ${requests_mem} ] && { echo_red "requests_mem is Required, Please set it"; exit -1; }
    [ -z ${limits_cpu} ] && { echo_red "limits_cpu is Required, Please set it"; exit -1; }
    [ -z ${limits_mem} ] && { echo_red "limits_mem is Required, Please set it"; exit -1; }
}


create_sonarqube_pv(){
  echo """
  apiVersion: v1
  kind: PersistentVolume
  metadata:
    name: sonarqube-pv
    labels:
      pv: sonarqube-pv
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
      volumeHandle: ${file_system_id}:/sonarqube
  """ | kubectl apply -f -
}

create_sonarqube_pvc(){
  echo """
  apiVersion: v1
  kind: PersistentVolumeClaim
  metadata:
    name: sonarqube-pvc
    namespace: ${namespace}
  spec:
    accessModes:
      - ReadWriteMany
    storageClassName: ''
    resources:
      requests:
        storage: 5Ti
    selector:
      matchLabels:
        pv: sonarqube-pv
  """ | kubectl apply -f -
  sonarqube_pvc_status=$(kubectl -n ${namespace} get pvc sonarqube-pvc | grep Bound | wc -l)
  [ ${sonarqube_pvc_status} == 1 ] && echo "sonarqube pv pvc创建成功" || { echo_red "sonarqube pv pvc创建失败"; exit -1; }
}

# 校验config配置
verify_config

# 创建Jenkins pv pvc
echo_green "step1. 创建sonarqube-pv、sonarqube-pvc"
[ $(kubectl get pv sonarqube-pv 2>/dev/null | wc -l ) == 0 ] && { echo "创建sonarqube-pv"; create_sonarqube_pv; } || { echo "sonarqube-pv已存在，不需创建"; }
[ $(kubectl -n ${namespace} get pvc sonarqube-pvc 2>/dev/null | wc -l ) == 0 ] && { echo "创建sonarqube-pvc"; create_sonarqube_pvc; } || { echo "命名空间${namespace}下sonarqube-pvc已存在，不需创建"; }

# 使用helm搭建Jenkins
echo_green "step2. helm部署Sonarqube"
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
--set-string jvmOpts="${sonarqube_javaopts}"


# 检查jenkins statefulset启动状态
echo_green "step4. 检查sonarqube状态"
kubectl -n ${namespace} rollout status deployment sonarqube-sonarqube --timeout 10m

[ $? == 0 ] && { echo_green "sonarqube部署成功"; } || { echo_red "sonarqube部署失败"; }

