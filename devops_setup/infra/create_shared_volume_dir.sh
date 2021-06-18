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
  ${namespace} \

# create shared volume dir
logger_info "step1. Create shared volume dir /jenkins、/gitlab、/sonarqube、/jenkins-slave"
kubectl -n ${namespace} exec -it busybox -- mkdir -p /data/jenkins /data/jenkins-slave /data/gitlab /data/sonarqube

[ $(kubectl -n ${namespace} exec -it busybox ls /data/ | grep jenkins | wc -l) != 0 ] && { logger_info "create dir /jenkins successful"; } || { logger_error "create dir /jenkins failed"; exit 110; }
[ $(kubectl -n ${namespace} exec -it busybox ls /data/ | grep gitlab | wc -l) != 0 ] && { logger_info "create dir /gitlab successful"; } || { logger_error "create dir /gitlab failed"; exit 110; }
[ $(kubectl -n ${namespace} exec -it busybox ls /data/ | grep sonarqube | wc -l) != 0 ] && { logger_info "create dir /sonarqube successful"; } || { logger_error "create dir /sonarqube failed"; exit 110; }
[ $(kubectl -n ${namespace} exec -it busybox ls /data/ | grep jenkins-slave | wc -l) != 0 ] && { logger_info "create dir /jenkins-slave successful"; } || { logger_error "create dir /jenkins-slave failed"; exit 110; }