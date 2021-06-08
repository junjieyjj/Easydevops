#!/usr/bin/bash
SCRIPT_BASEDIR=$(dirname "$0")

cd ${SCRIPT_BASEDIR}
SCRIPT_BASEDIR="$PWD"
PROJECT_BASEDIR=$(dirname "${SCRIPT_BASEDIR}")

# include lib/*
source ${PROJECT_BASEDIR}/lib/*

# include config
if [ -z $(ps -p $PPID o cmd | grep install.sh | wc -l) ];then
  [ -f "${SCRIPT_BASEDIR}/config" ] && { source ${SCRIPT_BASEDIR}/config; } || { echo_red "${SCRIPT_BASEDIR}/config not exist"; exit -1; }
else
  [ -f "${PROJECT_BASEDIR}/config" ] && { source ${PROJECT_BASEDIR}/config; } || { echo_red "${PROJECT_BASEDIR}/config not exist"; exit -1; }
fi



create_namespace(){
    kubectl create ns ${namespace}
}

create_devops_dir(){
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
      - ReadWriteOnce
    persistentVolumeReclaimPolicy: Retain
    storageClassName: ""
    csi:
      driver: efs.csi.aws.com
      volumeHandle: ${file_system_id}
  """ | kubectl apply -f -

  # 创建busybox-pvc
  echo """
  apiVersion: v1
  kind: PersistentVolumeClaim
  metadata:
    name: busybox-pvc
    namespace: ${namespace}
  spec:
    accessModes:
      - ReadWriteOnce
    storageClassName: ''
    resources:
      requests:
        storage: 5Gi
    selector:
      matchLabels:
        pv: busybox-pv
  """ | kubectl apply -f -

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
  sleep 15
  [ $(kubectl -n ${namespace} exec -it busybox ls /data/ | grep ^jenkins$ | wc -l) != 0 ] && { echo "/jenkins目录创建成功"; } || { echo "/jenkins目录创建失败"; }
  [ $(kubectl -n ${namespace} exec -it busybox ls /data/ | grep gitlab | wc -l) != 0 ] && { echo "/gitlab目录创建成功"; } || { echo "/gitlab目录创建失败"; }
  [ $(kubectl -n ${namespace} exec -it busybox ls /data/ | grep sonarqube | wc -l) != 0 ] && { echo "/sonarqube目录创建成功"; } || { echo "/sonarqube目录创建失败"; }
  [ $(kubectl -n ${namespace} exec -it busybox ls /data/ | grep jenkins-slave | wc -l) != 0 ] && { echo "/jenkins-slave目录创建成功"; } || { echo "/jenkins-slave目录创建失败"; }

}

# 创建命名空间
echo_green "step1. 创建命名空间${namespace}"
create_namespace

# 创建efs持久化目录
echo_green "step2. 创建持久化目录/jenkins、/gitlab、/sonarqube、/jenkins-slave"
echo_green "setp6. 清理busybox资源"
# 删除busybox pod
kubectl -n ${namespace} delete pod busybox
kubectl -n ${namespace} delete pvc busybox-pvc
kubectl -n ${namespace} delete pv busybox-pv
create_devops_dir

