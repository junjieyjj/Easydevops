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
  ${busybox_image} 

# create namespace
logger_info "step1. Create namespace ${namespace}"
create_namespace ${namespace} 

# delete busybox resources
logger_info "setp2. Celete busybox resources"
kubectl -n ${namespace} delete pod busybox
kubectl -n ${namespace} delete pvc busybox-pvc
kubectl -n ${namespace} delete pv busybox-pv

logger_info "step3. Create busybox-pv、busybox-pvc"
create_efs_pv_without_subpath ${file_system_id} busybox-pv 
check_pv_status busybox-pv
create_efs_pvc ${namespace} busybox-pvc busybox-pv
check_pvc_status ${namespace} busybox-pvc

# create busybox
logger_info "step4. Create busybox pod"
crate_pod ${namespace} busybox ${busybox_image} /data busybox-pvc
check_k8s_pod_status ${namespace} busybox