create_efs_pv(){
    local file_system_id=$1
    local pv_name=$2
    local sub_path=$3
  echo """
  apiVersion: v1
  kind: PersistentVolume
  metadata:
    name: ${pv_name}
    labels:
      pv: ${pv_name}
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
      volumeHandle: ${file_system_id}:/${sub_path}
  """ | kubectl apply -f -
}

create_efs_pv_without_subpath(){
    local file_system_id=$1
    local pv_name=$2
  echo """
  apiVersion: v1
  kind: PersistentVolume
  metadata:
    name: ${pv_name}
    labels:
      pv: ${pv_name}
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
      volumeHandle: ${file_system_id}
  """ | kubectl apply -f -
}

create_efs_pvc(){
    local namespace=$1
    local pvc_name=$2
    local bind_pv_name=$3
  echo """
  apiVersion: v1
  kind: PersistentVolumeClaim
  metadata:
    name: ${pvc_name}
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
        pv: ${bind_pv_name}
  """ | kubectl apply -f -
}

