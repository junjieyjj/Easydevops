CURDIR=$(cd $(dirname ${BASH_SOURCE[0]}); pwd )
PROJECT_BASE_DIR=$(dirname ${CURDIR})

source ${CURDIR}/efs_storage.sh
source ${CURDIR}/ebs_storage.sh
source ${CURDIR}/flexvolume_storage.sh

create_namespace(){
    local namespace=$1
    kubectl create ns ${namespace} || echo '[INFO] namespace already exists, not create again'
}

create_pv(){
    # AWS: efs、ebs
    # Aliyun: flexvolume
    local storage_type=$1
    case "${storage_type}" in
    "efs")
        create_efs_pv
        ;;
    "ebs")
        echo "in developing" 
        ;;
    "flexvolume")
        echo "in developing" 
        ;;
    *)
        echo "unknown storage_type" 
        exit 110
        ;;
    esac
}

create_pvc(){
    # AWS: efs、ebs
    # Aliyun: flexvolume
    local storage_type=$1
    case "${storage_type}" in
    "efs")
        create_efs_pvc
        ;;
    "ebs")
        echo "in developing" 
        ;;
    "flexvolume")
        echo "in developing" 
        ;;
    *)
        echo "unknown storage_type" 
        exit 110
        ;;
    esac
}

create_cluster_role(){
    local name=$1
  echo """
  kind: ClusterRole
  apiVersion: rbac.authorization.k8s.io/v1beta1
  metadata:
    name: ${name}
  rules:
    - apiGroups: ['extensions', 'apps']
      resources: ['deployments']
      verbs: ['create', 'delete', 'get', 'list', 'watch', 'patch', 'update']
    - apiGroups: ['']
      resources: ['services']
      verbs: ['create', 'delete', 'get', 'list', 'watch', 'patch', 'update']
    - apiGroups: ['']
      resources: ['pods']
      verbs: ['create','delete','get','list','patch','update','watch']
    - apiGroups: ['']
      resources: ['pods/exec']
      verbs: ['create','delete','get','list','patch','update','watch']
    - apiGroups: ['']
      resources: ['pods/log']
      verbs: ['get','list','watch']
    - apiGroups: ['']
      resources: ['secrets']
      verbs: ['get']
    - apiGroups: ['']
      resources: ['events']
      verbs: ['get','list','watch']
  """ | kubectl apply -f -
}

create_cluster_rolebinding(){
    local name=$1
    local binding_cluster_role=$2
    local service_account_name=$3
    local namespace=$4
  echo """
  apiVersion: rbac.authorization.k8s.io/v1beta1
  kind: ClusterRoleBinding
  metadata:
    name: ${name}
    namespace: ${namespace}
  roleRef:
    apiGroup: rbac.authorization.k8s.io
    kind: ClusterRole
    name: ${binding_cluster_role}
  subjects:
    - kind: ServiceAccount
      name: ${service_account_name}
      namespace: ${namespace}
  """ | kubectl create -f -
}

create_pod(){
  local namespace=$1
  local name=$2
  local image=$3
  local mount_path=$4
  local pvc_name=$5
  echo """
  apiVersion: v1
  kind: Pod
  metadata:
    name: ${name}
    namespace: ${namespace}
  spec:
    containers:
    - name: app
      image: ${image}
      command: ['/bin/sh']
      args: ['-c', 'sleep 1000000000']
      volumeMounts:
      - name: persistent-storage
        mountPath: /data
    volumes:
    - name: persistent-storage
      persistentVolumeClaim:
        claimName: busybox-pvc
    """ | kubectl apply -f -
}