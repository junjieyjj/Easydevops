create_efs_pv(){
    file_system_id=$1
    pv_name=$2
    sub_path=$3
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

create_efs_pvc(){
    file_system_id=$1
    namespace=$2
    pvc_name=$3
    bind_pv_name=$4
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

