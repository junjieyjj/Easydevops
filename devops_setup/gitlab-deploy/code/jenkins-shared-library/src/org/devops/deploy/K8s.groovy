#!groovy
package org.devops.deploy
import org.devops.*

def call(Map METADATA) {
    def log = new Log()
    def k8sUtils = new org.devops.kubernetes.Utils()

    log.info ("使用K8s发布")
    // 检查Kube-Config凭证
    k8sUtils.checkKubeConfigCredentials("${KUBECONF_CREDENTIAL_ID}")
    // 创建命名空间
    k8sUtils.createNamespace()
    // 创建Secret - 键值对类型（用于挂载Secret到环境变量）
    // k8sUtils.createSecretFromEnvFile()
    // 目标命名空间中创建Docker_Registry_Secret
    // k8sUtils.createDockerRegistrySecret("${Docker_RemoteRegistry}", "${Docker_RemoteRegistry_Secret}")

    // 渲染部署脚本，生成YAML文件，执行部署
    k8sUtils.generate_Yaml_And_Deploy(METADATA)

    // 监视部署进度、超时失败自动回滚、Debug信息打印
    k8sUtils.monitor_Deploy_and_rollback(METADATA)


}



