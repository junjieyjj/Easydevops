#!/usr/bin/bash

check_port_listen(){
  local port=${1-"80"}
  local host=${2-"127.0.0.1"}
  local timeout=${3-"2"}
  local retry_times=${4-"5"}
  local n=0
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
  local port=${1-"80"}
  local timeout=${2-"2"}
  local retry_times=${3-"5"}
  local n=0
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
  local url=$1
  local timeout=${2-"2"}
  local retry_times=${3-"5"}
  local n=0
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
  local user=$1
  local host=${2-"127.0.0.1"}
  local port=${3-"22"}
  ssh -v -p ${port} ${user}@${host} > /dev/null 2>&1
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
  local pv_name=$1
  local pv_status=$(kubectl get pv | grep ${pv_name} | wc -l)
  [ ${pv_status} == 1 ] && echo "create ${pv_name} pv successful" || { echo "ERROR: create ${pv_name} pv failed"; exit 110; }
}

check_pvc_status(){
  local namespace=$1
  local pvc_name=$2
  local pvc_status=$(kubectl -n ${namespace} get pvc ${pvc_name} | grep Bound | wc -l)
  [ ${pvc_status} == 1 ] && echo "create ${pvc_name} pvc successful" || { echo "ERROR: create ${pv_name} pvc failed"; exit 110; }
}

verify_params_null(){
  for arg in "$@"; do
      [ -z ${arg} ] && { echo "ERROR: ${arg} is Required, Please set it"; exit 110; }
  done
}

check_k8s_pod_status(){
  local namespace=${1}
  local pod=${2}
  local timeout=${3-"10"}
  local retry_times=${4-"5"}
  local n=0
  until [ "$n" -ge ${retry_times} ]
  do
    kubectl -n ${namespace} get pod ${pod} | grep Running > /dev/null
    [ $? -eq 0 ] && break || echo "wait pod ${pod} start..."
    n=$((n+1)) 
    sleep ${timeout}
  done
  [ "$n" -eq ${retry_times} ] && { echo "ERROR: pod ${pod} start failed"; exit 110; }
}

check_cluster_role(){
  local cluster_role=$1
  local cluster_role_exist=$(kubectl get clusterrole | grep ${cluster_role} | wc -l)
  [ ${cluster_role_exist} == 1 ] && echo "create ${cluster_role} clusterrole successful" || { echo "ERROR: create ${cluster_role} clusterrole failed"; exit 110; }
}

check_cluster_rolebinding(){
  local namespace=$1
  local cluster_role_binding=$2
  local cluster_role_binding_exist=$(kubectl -n ${namespace} get clusterrolebindings | grep ${cluster_role_binding} | wc -l)
  [ ${cluster_role_binding_exist} == 1 ] && echo "create ${cluster_role_binding} clusterrolebinding successful" || { echo "ERROR: create ${cluster_role_binding} clusterrole failed"; exit 110; }
}

check_ingress(){
  local namespace=$1
  local name=$2
  local ingress_exist=$(kubectl -n ${namespace} get ingress | grep ${name} | wc -l)
  [ ${ingress_exist} == 1 ] && echo "create ${name} ingress successful" || { echo "ERROR: create ${name} ingress failed"; exit 110; }
}