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
    [ -z ${gitlab_root_password} ] && { echo_red "gitlab_root_password is Required, Please set it"; exit -1; }
    [ -z ${gitlab_external_url} ] && { echo_red "gitlab_external_url is Required, Please set it"; exit -1; }
    [ -z ${gitlab_image} ] && { echo_red "gitlab_image is Required, Please set it"; exit -1; }
    [ -z ${namespace} ] && { echo_red "namespace is Required, Please set it"; exit -1; }
    [ -z ${requests_cpu} ] && { echo_red "requests_cpu is Required, Please set it"; exit -1; }
    [ -z ${requests_mem} ] && { echo_red "requests_mem is Required, Please set it"; exit -1; }
    [ -z ${limits_cpu} ] && { echo_red "limits_cpu is Required, Please set it"; exit -1; }
    [ -z ${limits_mem} ] && { echo_red "limits_mem is Required, Please set it"; exit -1; }
    [ -z ${gitlab_postgresql_db_host} ] && { echo_red "gitlab_postgresql_db_host is Required, Please set it"; exit -1; }
    [ -z ${gitlab_postgresql_db_database} ] && { echo_red "gitlab_postgresql_db_database is Required, Please set it"; exit -1; }
    [ -z ${gitlab_postgresql_db_username} ] && { echo_red "gitlab_postgresql_db_username is Required, Please set it"; exit -1; }
    [ -z ${gitlab_postgresql_db_password} ] && { echo_red "gitlab_postgresql_db_password is Required, Please set it"; exit -1; }
    [ -z ${gitlab_postgresql_db_port} ] && { echo_red "gitlab_postgresql_db_port is Required, Please set it"; exit -1; }
    [ -z ${gitlab_redis_host} ] && { echo_red "gitlab_redis_host is Required, Please set it"; exit -1; }
    [ -z ${gitlab_redis_port} ] && { echo_red "gitlab_redis_port is Required, Please set it"; exit -1; }
}


create_gitlab_pv(){
  echo """
  apiVersion: v1
  kind: PersistentVolume
  metadata:
    name: gitlab-pv
    labels:
      pv: gitlab-pv
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
      volumeHandle: ${file_system_id}:/gitlab
  """ | kubectl apply -f -
}

create_gitlab_pvc(){
  echo """
  apiVersion: v1
  kind: PersistentVolumeClaim
  metadata:
    name: gitlab-pvc
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
        pv: gitlab-pv
  """ | kubectl apply -f -
  gitlab_pvc_status=$(kubectl -n ${namespace} get pvc gitlab-pvc | grep Bound | wc -l)
  [ ${gitlab_pvc_status} == 1 ] && echo "gitlab pv pvc创建成功" || { echo_red "gitlab pv pvc创建失败"; exit -1; }
}

# 校验config配置
verify_config

# 创建Jenkins pv pvc
echo_green "step1. 创建gitlab-pv、gitlab-pvc"
[ $(kubectl get pv gitlab-pv 2>/dev/null | wc -l ) == 0 ] && { echo "创建gitlab-pv"; create_gitlab_pv; } || { echo "gitlab-pv已存在，不需创建"; }
[ $(kubectl -n ${namespace} get pvc gitlab-pvc 2>/dev/null | wc -l ) == 0 ] && { echo "创建gitlab-pvc"; create_gitlab_pvc; } || { echo "命名空间${namespace} gitlab-pvc已存在，不需创建"; }

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


# 使用helm搭建Jenkins
echo_green "step2. helm部署Gitlab"
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
-f gitlab.yaml

# 检查jenkins statefulset启动状态
echo_green "step3. 检查gitlab状态"
kubectl -n ${namespace} rollout status statefulset gitlab --timeout 5m

[ $? == 0 ] && { echo_green "gitlab部署成功"; } || { echo_red "gitlab部署失败"; }


