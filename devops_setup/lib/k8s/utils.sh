CURDIR=$(cd $(dirname ${BASH_SOURCE[0]}); pwd )
PROJECT_BASE_DIR=$(dirname ${CURDIR})

source ${CURDIR}/efs_storage.sh
source ${CURDIR}/ebs_storage.sh
source ${CURDIR}/flexvolume_storage.sh

create_namespace(){
    namespace=$1
    kubectl create ns ${namespace}
}

create_pv(){
    # AWS: efs、ebs
    # Aliyun: flexvolume
    storage_type=$1
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
    storage_type=$1
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
    name=$1
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
    name=$1
    binding_cluster_role=$2
    service_account_name=$3
    namespace=$4
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