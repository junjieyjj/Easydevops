#!groovy
package org.devops.kubernetes
import org.devops.kubernetes.Init

// 检查KubeConfig凭证
def checkKubeConfigCredentials(String kube_Credentials_Id) {
    try {
        withCredentials([file(credentialsId: "${kube_Credentials_Id}", variable: "kube_Credentials")]) {
            println "***INFO：当前K8s使用的凭证为：${kube_Credentials_Id}"
        }
    }
    catch (any) {
        error "***WARN：找不到K8s凭证，请确认凭证是否正确，当前K8s使用的凭证为：${kube_Credentials_Id}。"
    }
}

// 创建命名空间
def createNamespace() {
    String kubeconf = "${KUBECONF}"
    String namespace = "${NAMESPACE}"

    sh """
        set +x
        echo ***INFO：创建命名空间 ${namespace}
        kubectl --kubeconfig=${kubeconf} create namespace ${namespace} || echo ***INFO：要创建的命名空间已存在，忽略创建。
       """
}

// 创建ConfigMap - 文件类型
def createConfigMapFromConfigFile() {
    String kubeconf = "${KUBECONF}"
    String namespace = "${NAMESPACE}"
    String projectName = "${PROJECT_NAME}"
    String configFilePath = "./${NAMESPACE}/"

    // 判断对应环境目录是否存在
    if (fileExists(configFilePath)) {
        sh """
            set +x
            echo ***INFO：打印 ${configFilePath} 目录下文件列表
            ls -lha --time-style=long-iso ${configFilePath} | tail -n +2
            echo
            
            echo ***INFO：读取 ${configFilePath} 目录下配置文件，生成configmap.yaml
            kubectl --kubeconfig=${kubeconf} create configmap ${projectName}-conf \
            --namespace=${namespace} \
            --from-file=${configFilePath} \
            -o yaml --dry-run=true > ./configmap.yaml
            echo
            
            echo ***INFO：应用ConfigMap-Conf
            kubectl --kubeconfig=${kubeconf} apply -f ./configmap.yaml
            echo
            
            echo ***INFO：查看ConfigMap-Conf
            kubectl --kubeconfig=${kubeconf} get configmap ${projectName}-conf --namespace=${namespace}
        """
    } else {
        sh """
            set +x
            echo ***ERROR：找不到对应环境的Config目录 ${namespace} 本次发布异常中断退出。
            exit 1
            """
    }
}

// 创建Secret - 键值对类型（用于挂载Secret到环境变量）
def createSecretFromEnvFile() {
    String kubeconf = "${KUBECONF}"
    String namespace = "${NAMESPACE}"
    String projectName = "${PROJECT_NAME}"
    String envFilePath = "./AppMetadata/${PROJECT_GROUP_NAME}/${PROJECT_NAME}/secret/"
    String envFile = envFilePath + "${NAMESPACE}.env"

    if (envFile) {
        sh """
            set +x
            echo ***INFO：打印 ${envFilePath} 目录下文件列表
            ls -lha --time-style=long-iso ${envFilePath} | tail -n +2
            echo
            
            echo ***INFO：读取对应环境配置文件，生成secret.yaml
            kubectl --kubeconfig=${kubeconf} create secret generic ${projectName}-secret \
            --namespace=${namespace} \
            --from-env-file=${envFile} \
            -o yaml --dry-run=true > ./secret.yaml
            echo

            echo ***INFO：应用Secret
            kubectl --kubeconfig=${kubeconf} apply -f ./secret.yaml
            echo
            
            echo ***INFO：查看Secret
            kubectl --kubeconfig=${kubeconf} get secret ${projectName}-secret --namespace=${namespace}
            """
    } else {
        sh """
            set +x
            echo ***ERROR：找不到对应环境的Secret文件 ${envFile} 本次发布异常中断退出。
            exit 1
            """
    }
}

// 为当前命名空间默认服务账户创建DockerRegistrySecret
def createDockerRegistrySecret(String docker_Registry_Url, String docker_Registry_Secret) {
    withCredentials([usernamePassword(credentialsId: docker_Registry_Secret, passwordVariable: 'DockerPassword', usernameVariable: 'DockerUser')]) {
        RANDON = UUID.randomUUID().toString().tokenize('-')[-1]
        try {
            sh """
                set +x
                echo ***INFO：检查Docker-Registry-Secret是否已存在
                kubectl --kubeconfig=${KUBECONF} get secret ${docker_Registry_Secret} --namespace=${NAMESPACE}

                echo ***INFO：已存在Docker-Registry-Secret
                echo ***INFO：创建临时Docker-Registry-Secret并获取其内容
                kubectl --kubeconfig=${KUBECONF} create secret docker-registry ${docker_Registry_Secret}-tmp-${RANDON} \
                --namespace=${NAMESPACE} \
                --docker-server=${docker_Registry_Url} \
                --docker-username=${DockerUser} \
                --docker-password=${DockerPassword}

                # 获取临时Docker-Registry-Secret内容
                tmpsecret=`kubectl --kubeconfig=${KUBECONF} get secret ${docker_Registry_Secret}-tmp-${RANDON} --namespace=${NAMESPACE} -o jsonpath={.data.*}`

                echo ***INFO：删除临时Docker-Registry-Secret
                kubectl --kubeconfig=${KUBECONF} delete secret ${docker_Registry_Secret}-tmp-${RANDON} --namespace=${NAMESPACE}
                echo ***INFO：使用临时Docker-Registry-Secret Patch Docker-Registry-Secret
                kubectl --kubeconfig=${KUBECONF} patch secret ${docker_Registry_Secret} -p "{\\"data\\": {\\".dockerconfigjson\\": \\"\${tmpsecret}\\"}}" --namespace=${NAMESPACE}
                """
        }
        catch (any) {
            sh """
            set +x
                echo ***INFO：创建Docker-Registry类型Secret
                #kubectl --kubeconfig=${KUBECONF} delete secret ${docker_Registry_Secret} --namespace=${NAMESPACE} || echo ***WARN：不存在DockerRegistrySecret，删除出错，进行容错处理，忽略。
                kubectl --kubeconfig=${KUBECONF} create secret docker-registry ${docker_Registry_Secret} --namespace="${NAMESPACE}" \
                --docker-server=${docker_Registry_Url} \
                --docker-username=${DockerUser} \
                --docker-password=${DockerPassword}
            """
        }
        finally {
            sh """
            set +x
                echo ***INFO：修改命名空间的默认服务帐户以此Registry-Secret用作默认imagePullSecret
                kubectl --kubeconfig=${KUBECONF} patch serviceaccount default -p \'{"imagePullSecrets": [{"name": "'${docker_Registry_Secret}'"}]}\'  --namespace=${NAMESPACE}
                echo ***INFO：获取当前命名空间默认服务账户配置，用于确认Registry-Secret
                kubectl --kubeconfig=${KUBECONF} get serviceaccounts default --namespace="${NAMESPACE}" -o yaml
            """
        }
    }
}

// 渲染生成YAML文件，发布项目
def generate_Yaml_And_Deploy(Map METADATA) {
/*  不开启configmap和secret功能
          --set-string configMap_env=''' + configMap_env + ''' \
          --set-string configMap_conf=''' + configMap_conf + ''' \
*/
    env.HELM_TEMPLATE = METADATA.HELM_TEMPLATE
    env.DOCKER_REGISTRY_HOST = METADATA.DOCKER_REGISTRY_HOST ?: env.DOCKER_REGISTRY_HOST
    // env.REPLICA_COUNT
    // 设置默认资源限制
    env.CPU_LIMIT = env.CPU ?: 1
    env.CPU_REQUEST = env.CPU ?: 1
    env.MEM_LIMIT = env.MEM ?: 1
    env.MEM_REQUEST = env.MEM ?: 1
    
    def init = new Init()
    init.set_default_helm_values(env.HELM_TEMPLATE)

    sh '''
        set -x
        APP_PATH=./AppMetadata/${PROJECT_GROUP_NAME}/${PROJECT_NAME}
        echo ***INFO：使用Jenkins参数渲染默认defalut-values.yaml
        envsubst < ./HelmTemplate/DefaultHelmValues/${HELM_TEMPLATE}.yaml.template > ${APP_PATH}/default-values.yaml
        cat ${APP_PATH}/default-values.yaml
        GIT_HASH=$(echo ${BUILD_TAG} | awk -F'-' '{print $NF}')
        ls -lrt ${APP_PATH}
          echo ***INFO：使用 ${HELM_TEMPLATE} 模板渲染生成K8s部署文件
          # 根据选择的渲染模板，使用helm template生成yaml到${APP_PATH}/deploy.yaml
          [ -f ${APP_PATH}/helm_values.yaml ] && { VAULES_YAML="-f ${APP_PATH}/helm_values.yaml"; } || { VAULES_YAML=''; }
          helm template ./HelmTemplate/${HELM_TEMPLATE}/ \
          --set appname=${PROJECT_NAME} \
          --set project=${PROJECT_GROUP_NAME} \
          --set namespace=${NAMESPACE} \
          --set image.repository=${DOCKER_REGISTRY_HOST} \
          --set gitcommit=${GIT_HASH} \
          --set-string version=${VERSION} \
          --set-string build_tag=${BUILD_TAG} -f ${APP_PATH}/default-values.yaml ${VAULES_YAML} \
          > ${APP_PATH}/deploy.yaml

          echo ***INFO：开始部署项目
          set -x
          kubectl --kubeconfig=${KUBECONF} apply -f ${APP_PATH}/deploy.yaml
    '''
}

// 监视部署进度、超时失败自动回滚处理
def monitor_Deploy_and_rollback(Map METADATA) {
    env.K8S_DEPLOY_NAME = env.PROJECT_NAME
    // 监视部署进度
    try {
        sh 'set +x && echo ***INFO：监视部署进度（异常超时为10分钟，超时后会自动回滚撤销本次发布） && kubectl --kubeconfig=${KUBECONF}  rollout status deploy ${K8S_DEPLOY_NAME} -w --namespace=${NAMESPACE}'
    }
    // 进行容错处理，发布异常时自动回滚
    catch (any) {
        sh '''
            set +x
            echo ***WARN：发布异常。
            echo ""
            echo ***WARN：发布异常，获取相关Events信息 && kubectl --kubeconfig=${KUBECONF} get events --namespace=${NAMESPACE} | grep "^LAST SEEN\\|$(kubectl --kubeconfig=${KUBECONF}  describe deploy ${K8S_DEPLOY_NAME} --namespace=${NAMESPACE} | grep "^NewReplicaSet\\|^OldReplicaSets" |awk \'{print $2}\' | grep -v "^<none>")"
            echo ""
            echo ***WARN：发布异常，获取异常POD的信息。&& kubectl --kubeconfig=${KUBECONF}  describe pod $(kubectl --kubeconfig=${KUBECONF}  get pod -l app=${PROJECT_NAME},version=${VERSION} --namespace=${NAMESPACE} -o wide | grep "0/1" | head -n 1 | awk \'{print $1}\') --namespace=${NAMESPACE}
            echo ""
            echo ***WARN：发布异常，执行自动回滚。&& kubectl --kubeconfig=${KUBECONF}  rollout undo deploy ${K8S_DEPLOY_NAME} --namespace=${NAMESPACE}
            echo ""
            echo ***INFO：监视回滚进度 && kubectl --kubeconfig=${KUBECONF}  rollout status deploy ${K8S_DEPLOY_NAME} -w --namespace=${NAMESPACE}
            echo ""
            echo ***ERROR：本次发布异常中断退出。&& exit 1
        '''
    }
    // 发布进度无论是否出错都打印项目信息
    finally {
        sh '''
            set +x
            # echo ***INFO：输出Events信息 && kubectl --kubeconfig=${KUBECONF} get events --namespace=${NAMESPACE} | grep "^LAST SEEN\\|$(kubectl --kubeconfig=${KUBECONF}  describe deploy ${K8S_DEPLOY_NAME} --namespace=${NAMESPACE} | grep "^NewReplicaSet\\|^OldReplicaSets" |awk \'{print $2}\' | grep -v "^<none>")"
            # echo ""
            echo ***INFO：输出Service信息 && kubectl --kubeconfig=${KUBECONF}  get svc ${PROJECT_NAME} --namespace=${NAMESPACE} -o wide
            echo ""
            echo ***INFO：输出Deploy信息 && kubectl --kubeconfig=${KUBECONF}  get deploy ${K8S_DEPLOY_NAME} --namespace=${NAMESPACE} -o wide
            echo ""
            echo ***INFO：输出ReplicaSet信息 && kubectl --kubeconfig=${KUBECONF}  get rs $(kubectl --kubeconfig=${KUBECONF}  describe deploy ${K8S_DEPLOY_NAME} --namespace=${NAMESPACE} | grep "^NewReplicaSet\\|^OldReplicaSets" |awk \'{print $2}\' | grep -v "^<none>") --namespace=${NAMESPACE} -o wide
            echo ""
            echo ***INFO：输出Pod信息（列表） && kubectl --kubeconfig=${KUBECONF}  get pod -l app=${PROJECT_NAME},version=${VERSION} --namespace=${NAMESPACE} -o wide
            echo ""
            echo ***INFO：输出Pod信息-描述信息 && kubectl --kubeconfig=${KUBECONF}  describe pod $(kubectl --kubeconfig=${KUBECONF}  get pod -l app=${PROJECT_NAME},version=${VERSION} --namespace=${NAMESPACE} -o wide | tail -n1 | head -n 1 | awk \'{print $1}\') --namespace=${NAMESPACE}
            echo ""
            echo ***INFO：输出Deploy信息-描述信息 && kubectl --kubeconfig=${KUBECONF}  describe deploy ${K8S_DEPLOY_NAME} --namespace=${NAMESPACE} 
        '''
    }
}

