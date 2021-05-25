#!/usr/bin/bash

# 字体颜色
RED="\e[31m"
GREEN="\e[32m"
ENDCOLOR="\e[0m"

echo_green(){
  echo -e "${GREEN}${1} ${ENDCOLOR}"
}

echo_red(){
  echo -e "${RED}${1} ${ENDCOLOR}"
}

# 读取Jenkins配置
. ./config

# 校验config文件参数
verify_config(){
    [ -z ${AWS_ACCESS_KEY_ID} ] && { echo_red "AWS_ACCESS_KEY_ID is Required, Please set it"; exit -1; }
    [ -z ${AWS_SECRET_ACCESS_KEY} ] && { echo_red "AWS_SECRET_ACCESS_KEY is Required, Please set it"; exit -1; }
    [ -z ${AWS_DEFAULT_REGION} ] && { echo_red "AWS_DEFAULT_REGION is Required, Please set it"; exit -1; }
    [ -z ${EKS_CLUSTER} ] && { echo_red "EKS_CLUSTER is Required, Please set it"; exit -1; }
    [ -z ${AWS_ACCOUNT_ID} ] && { echo_red "AWS_ACCOUNT_ID is Required, Please set it"; exit -1; }
    [ -z ${s3_bucket_name} ] && { echo_red "s3_bucket_name is Required, Please set it"; exit -1; }
    [ -z ${file_system_id} ] && { echo_red "file_system_id is Required, Please set it"; exit -1; }
    [ -z ${busybox_image} ] && { echo_red "busybox_image is Required, Please set it"; exit -1; }
    [ -z ${jenkins_image} ] && { echo_red "jenkins_image is Required, Please set it"; exit -1; }
    [ -z ${jenkins_plugins_url} ] && { echo_red "jenkins_plugins_url is Required, Please set it"; exit -1; }
    [ -z ${namespace} ] && { echo_red "namespace is Required, Please set it"; exit -1; }
    [ -z ${requests_cpu} ] && { echo_red "requests_cpu is Required, Please set it"; exit -1; }
    [ -z ${requests_mem} ] && { echo_red "requests_mem is Required, Please set it"; exit -1; }
    [ -z ${limits_cpu} ] && { echo_red "limits_cpu is Required, Please set it"; exit -1; }
    [ -z ${limits_mem} ] && { echo_red "limits_mem is Required, Please set it"; exit -1; }
    [ -z "${jenkins_javaopts}" ] && { echo_red "jenkins_javaopts is Required, Please set it"; exit -1; }
}


create_jenkins_pv(){
  echo """
  apiVersion: v1
  kind: PersistentVolume
  metadata:
    name: jenkins-pv
    labels:
      pv: jenkins-pv
  spec:
    capacity:
      storage: 5Ti
    volumeMode: Filesystem
    accessModes:
      - ReadWriteOnce
    storageClassName: ""
    persistentVolumeReclaimPolicy: Retain
    csi:
      driver: efs.csi.aws.com
      volumeHandle: ${file_system_id}:/jenkins
  """ | kubectl apply -f -
}

create_jenkins_pvc(){
  # 创建jenkins pvc
  echo '
  apiVersion: v1
  kind: PersistentVolumeClaim
  metadata:
    name: jenkins-pvc
    namespace: devops
  spec:
    accessModes:
      - ReadWriteOnce
    storageClassName: ""
    resources:
      requests:
        storage: 5Ti
    selector:
      matchLabels:
        pv: jenkins-pv
  ' | kubectl apply -f -
  jenkins_pvc_status=$(kubectl -n ${namespace} get jenkins-pvc grep Bound | wc -l)
  [ ${jenkins_pvc_status} == 1 ] && echo "jenkins pv pvc创建成功" || { echo_red "jenkins pv pvc创建失败"; exit -1; }
}

# 校验config配置
verify_config

# 创建Jenkins pv pvc
echo_green "step1. 创建jenkins-pv、jenkins-pvc"
[ $(kubectl get pv jenkins-pv 2>/dev/null | wc -l ) == 0 ] && { echo "创建jenkins-pv"; create_jenkins_pv; } || { echo "jenkins-pv已存在，不需创建"; }
[ $(kubectl -n ${namespace} get pvc jenkins-pvc 2>/dev/null | wc -l ) == 0 ] && { echo "创建jenkins-pvc"; create_jenkins_pvc; } || { echo "命名空间${namespace}下jekins-pvc已存在，不需创建"; }


# 生成jcasc.yaml
echo_green "step2. 创建jcasc.yaml配置文件"
cat > jcasc.yaml << EOF
controller:
  customInitContainers: 
    - name: custom-init
      image: "${jenkins_image}"
      imagePullPolicy: Always
      command: 
        - "/bin/sh"
        - "-c"
        - "[ -d /var/jenkins_home/jenkins-3.3.9-plugins.tar.gz ] && (echo Dir:/var/jenkins_home/plugins is existed) || (cd /var/jenkins_home/; curl -O ${jenkins_plugins_url}; tar zxf jenkins-3.3.9-plugins.tar.gz)"
      resources:
        limits:
          cpu: "1"
          memory: 2Gi
        requests:
          cpu: 500m
          memory: 1Gi
      volumeMounts:
      - mountPath: /var/jenkins_home
        name: jenkins-home
  initScripts:
    - |
      def jcascFile = new File('/var/jenkins_home/casc_configs/jcasc.yaml')
      jcascFile.delete()
  JCasC:
    defaultConfig: true
    configScripts:
      jcasc: |
        jenkins:
          systemMessage: Welcome to CI\CD server.
          authorizationStrategy:
            roleBased:
              roles:
                global:
                  - name: "admin"
                    description: "Jenkins administrators"
                    permissions:
                      - "Overall/Administer"
                    assignments:
                      - "admin"
                  - name: "readonly"
                    description: "Read-only users"
                    permissions:
                      - "Overall/Read"
                      - "Job/Read"
                    assignments:
                      - "authenticated"
                items:
                  - name: "FolderA"
                    description: "Jobs in Folder A, but not the folder itself"
                    pattern: "A/.*"
                    permissions:
                      - "Job/Configure"
                      - "Job/Build"
                      - "Job/Delete"
                    assignments:
                      - "user1"
                      - "user2"
          securityRealm:
            local:
              allowsSignup: false
              users:
                - id: "admin"
                  password: "admin"
          globalNodeProperties:
          - envVars:
              env:
              - key: GITLAB_URL
                value: http://gitlab.demo.com
              - key: SONARQUBE_URL
                value: http://sonarqube.demo.com
        unclassified:
          location:
            adminAddress: demo@example.com
            url: https://jenkins.example.com
          globalLibraries:
            libraries:
              - name: "shared-pipeline-library"
                defaultVersion: master
                retriever:
                  modernSCM:
                    scm:
                      git:
                        remote: "git@gitlab.demo.com:devops/shared-pipeline-library.git"
                        credentialsId: gitlab-ssh-key
          gitlabconnectionconfig:
            connections:
              - apiTokenId: gitlab-api-token
                clientBuilderId: "autodetect"
                connectionTimeout: 20
                ignoreCertificateErrors: true
                name: "gitlab"
                readTimeout: 10
                url: "http://gitlab.demo.com"
          ansiColorBuildWrapper:
            globalColorMapName: xterm
        credentials:
          system:
            domainCredentials:
              - domain:
                  name: "devops"
                  description: "store devops secrets"
                credentials:
                  - basicSSHUserPrivateKey:
                      scope: GLOBAL
                      id: gitlab-ssh-key
                      username: demo
                      passphrase: ''
                      description: "gitlab-ssh-key"
                      privateKeySource:
                        directEntry:
                          privateKey: "SSH_PRIVATE_KEY"
                  - gitLabApiTokenImpl:
                      scope: SYSTEM
                      id: gitlab-api-token
                      apiToken: "BIND_TOKEN"
                      description: "gitlab-api-token"
EOF


# 使用helm搭建Jenkins
echo_green "step3. helm部署Jenkins"
helm upgrade jenkins ./jenkins \
--version 3.3.9 \
--namespace ${namespace} \
--create-namespace \
--install \
--debug \
--set controller.image=`echo ${jenkins_image} | awk -F: '{print $1}'` \
--set controller.tag=`echo ${jenkins_image} | awk -F: '{print $2}'` \
--set controller.updateStrategy.type=RollingUpdate \
--set controller.adminSecret=false \
--set controller.adminUser=admin \
--set controller.adminPassword=admin \
--set controller.installPlugins=false \
--set controller.overwritePlugins=false \
--set controller.overwritePluginsFromImage=false \
--set controller.initializeOnce=true \
--set persistence.enabled=true \
--set controller.serviceType=LoadBalancer \
--set-string controller.runAsUser=0 \
--set-string controller.fsGroup=0 \
--set-string controller.resources.requests.cpu=${requests_cpu} \
--set-string controller.resources.requests.memory=${requests_mem} \
--set-string controller.resources.limits.cpu=${limits_cpu} \
--set-string controller.resources.limits.memory=${limits_mem} \
--set-string controller.javaOpts="${jenkins_javaopts}" \
--set controller.JCasC.defaultConfig=false \
--set controller.sidecars.configAutoReload.enabled=false \
--set persistence.existingClaim=jenkins-pvc \
--set agent.enabled=true \
-f ./jcasc.yaml

# 检查jenkins statefulset启动状态
echo_green "step4. 检查jenkins状态"
kubectl -n ${namespace} rollout status statefulset jenkins --timeout 10m

[ $? == 0 ] && { echo_green "jenkins部署成功"; } || { echo_red "jenkins部署失败"; }

