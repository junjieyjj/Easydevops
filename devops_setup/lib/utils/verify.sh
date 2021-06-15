#!/usr/bin/bash

check_port_listen(){
  port=${1-"80"}
  host=${2-"127.0.0.1"}
  timeout=${3-"2"}
  retry_times=${4-"5"}
  n=0
  until [ "$n" -ge ${retry_times} ]
  do
    curl -s ${host}:${port} > /dev/null
    [ $? -eq 0 ] && break || echo "wait port ${port} listen..."
    n=$((n+1)) 
    sleep ${timeout}
  done
  [ "$n" -eq ${retry_times} ] && { echo "ERROR: listen port ${port} failed"; exit 110; }
}

check_local_port_listen(){
  port=${1-"80"}
  timeout=${2-"2"}
  retry_times=${3-"5"}
  n=0
  until [ "$n" -ge ${retry_times} ]
  do
    netstat -tnlup | grep -w ${port} > /dev/null
    [ $? -eq 0 ] && break || echo "wait port ${port} listen..."
    n=$((n+1)) 
    sleep ${timeout}
  done
  [ "$n" -eq ${retry_times} ] && { echo "ERROR: listen port ${port} failed"; exit 110; }
}

check_http(){
  url=$1
  timeout=${2-"2"}
  retry_times=${3-"5"}
  n=0
  until [ "$n" -ge ${retry_times} ]
  do
    status_code=$(curl -L -m 5 -s -o /dev/null -w %{http_code} ${url})
    [ ${status_code} -eq 200 ] && break || echo "url: ${url} return status code ${status_code}, retry ${n}"
    n=$((n+1)) 
    sleep ${timeout}
  done
  [ "$n" -eq ${retry_times} ] && { echo "ERROR: url return code not 200"; exit 110; }
}

check_ssh(){
  user=$1
  host=${2-"127.0.0.1"}
  port=${3-"22"}
  ssh -v -p ${port} ${user}@${host}
  [ $? -eq 0 ] && { echo "ssh test by user: ${user}, host: ${host}, port: ${port} successful"; } || { echo "ERROR: ssh test by user: ${user}, host: ${host}, port: ${port} failed"; exit 110; }
}

check_command_exist(){
  command -v ${1} >/dev/null 2>&1 || { echo >&2 "ERROR: command ${1} not found, please install"; exit 110; }
}

check_postgresql_pong(){
  echo "developing"
}

check_redis_pong(){
  echo "developing"
}

check_kubectl_command(){
  check_command_exist kubectl
  kubectl get node > /dev/null 2&>1 || { echo >&2 "ERROR: kubeconfig seens not configure, please set it"; exit 110; }
}

check_helm_command(){
  check_command_exist helm
  helm list > /dev/null 2&>1 || { echo >&2 "ERROR: kubeconfig seens not configure, please set it"; exit 110; }
}

check_awscli_command(){
  check_command_exist aws
  aws --version > /dev/null 2&>1 || { echo >&2 "ERROR: awscli not install"; exit 110; }
}

check_aws_env(){
  printenv | grep AWS_ACCESS_KEY_ID > /dev/null || { echo >&2 "ERROR: AWS_ACCESS_KEY_ID not set"; exit 110; }
  printenv | grep AWS_SECRET_ACCESS_KEY  > /dev/null || { echo >&2 "ERROR: AWS_SECRET_ACCESS_KEY not set"; exit 110; }
  printenv | grep AWS_DEFAULT_REGION  > /dev/null || { echo >&2 "ERROR: AWS_DEFAULT_REGION not set"; exit 110; }
}

check_pv_status(){
  pv_name=$1
  pv_status=$(kubectl get pv | grep ${pv_name} | wc -l)
  [ ${pv_status} == 1 ] && echo "create ${pv_name} pv successful" || { echo "ERROR: create ${pv_name} pv failed"; exit 110; }
}

check_pvc_status(){
  namespace=$1
  pvc_name=$2
  pvc_status=$(kubectl -n ${namespace} get pvc ${pvc_name} | grep Bound | wc -l)
  [ ${pvc_status} == 1 ] && echo "create ${pvc_name} pvc successful" || { echo "ERROR: create ${pv_name} pvc failed"; exit 110; }
}

verify_params_null(){
  for arg in "$@"; do
      [ -z ${arg} ] && { echo "ERROR: ${arg} is Required, Please set it"; exit 110; }
  done
}

check_k8s_pod_status(){
  namespace=${1}
  pod=${2}
  timeout=${3-"10"}
  retry_times=${4-"5"}
  n=0
  until [ "$n" -ge ${retry_times} ]
  do
    kubectl -n ${namespace} get pod ${pod} | grep Running > /dev/null
    [ $? -eq 0 ] && break || echo "wait pod ${pod} start..."
    n=$((n+1)) 
    sleep ${timeout}
  done
  [ "$n" -eq ${retry_times} ] && { echo "ERROR: pod ${pod} start failed"; exit 110; }
}
