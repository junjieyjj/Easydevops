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


create_busybox_pv(){
  echo """
  apiVersion: v1
  kind: PersistentVolume
  metadata:
    name: busybox-pv
    labels:
      pv: busybox-pv
  spec:
    capacity:
      storage: 5Gi
    volumeMode: Filesystem
    accessModes:
      - ReadWriteMany
    persistentVolumeReclaimPolicy: Retain
    storageClassName: ""
    csi:
      driver: efs.csi.aws.com
      volumeHandle: ${file_system_id}
  """ | kubectl apply -f -
}

create_busybox_pvc(){
  # 创建busybox-pvc
  echo """
  apiVersion: v1
  kind: PersistentVolumeClaim
  metadata:
    name: busybox-pvc
    namespace: ${namespace}
  spec:
    accessModes:
      - ReadWriteMany
    storageClassName: ''
    resources:
      requests:
        storage: 5Gi
    selector:
      matchLabels:
        pv: busybox-pv
  """ | kubectl apply -f -
}

create_devops_dir(){
  # 创建busybox pod预创建目录    
  echo """
  apiVersion: v1
  kind: Pod
  metadata:
    name: busybox
    namespace: ${namespace}
  spec:
    containers:
    - name: app
      image: ${busybox_image}
      command: ['/bin/sh']
      args: ['-c', 'mkdir -p /data/jenkins /data/jenkins-slave /data/gitlab /data/sonarqube; sleep 1000000000']
      volumeMounts:
      - name: persistent-storage
        mountPath: /data
    volumes:
    - name: persistent-storage
      persistentVolumeClaim:
        claimName: busybox-pvc
    """ | kubectl apply -f -
  check_k8s_pod_status ${namespace} busybox
}

# check aws config
check_aws_env

# check config params
verify_params_null \
  ${file_system_id} \
  ${namespace} \
  ${busybox_image} 

# create namespace
logger_info "step1. create namespace ${namespace}"
create_namespace ${namespace} 

# delete busybox resources
logger_info "setp2. delete busybox resources"
kubectl -n ${namespace} delete pod busybox
kubectl -n ${namespace} delete pvc busybox-pvc
kubectl -n ${namespace} delete pv busybox-pv

logger_info "step3. create busybox-pv、busybox-pvc"
create_busybox_pv
check_pv_status busybox-pv
create_busybox_pvc
check_pvc_status ${namespace} busybox-pvc

# create efs dir
logger_info "step2. create busybox pod and create shared volume dir, /jenkins、/gitlab、/sonarqube、/jenkins-slave"
create_devops_dir
[ $(kubectl -n ${namespace} exec -it busybox ls /data/ | grep jenkins | wc -l) != 0 ] && { logger_info "create dir /jenkins successful"; } || { logger_error "create dir /jenkins failed"; exit 110; }
[ $(kubectl -n ${namespace} exec -it busybox ls /data/ | grep gitlab | wc -l) != 0 ] && { logger_info "create dir /gitlab successful"; } || { logger_error "create dir /gitlab failed"; exit 110; }
[ $(kubectl -n ${namespace} exec -it busybox ls /data/ | grep sonarqube | wc -l) != 0 ] && { logger_info "create dir /sonarqube successful"; } || { logger_error "create dir /sonarqube failed"; exit 110; }
[ $(kubectl -n ${namespace} exec -it busybox ls /data/ | grep jenkins-slave | wc -l) != 0 ] && { logger_info "create dir /jenkins-slave successful"; } || { logger_error "create dir /jenkins-slave failed"; exit 110; }