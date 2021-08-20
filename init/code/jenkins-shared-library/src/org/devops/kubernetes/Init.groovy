#!groovy
package org.devops.kubernetes

def set_default_helm_values(String helmTemplate) {
    if (helmTemplate == "EKSBackendJava") {
        sed_eks_backend_java_values()
    }
    else if (helmTemplate == "EKSFrontendNginx") {
        set_eks_frontend_nginx_values()
    }
}

def sed_eks_backend_java_values() {
    env.JVM_OPTS = getJvmOpts()
    env.APP_OPTS = getAppOpts()
}

def set_eks_frontend_nginx_values() {
    println "待实现"
}

// 根据CPU_LIMIT、MEM_LIMIT获取jvm参数
def getJvmOpts(){
    def map_jvm_opts = [
        "1": "-Xms256m -Xmx256m -Xss256k -XX:MetaspaceSize=128m -XX:MaxMetaspaceSize=128m -XX:ParallelGCThreads=${env.CPU_LIMIT} -XX:+UseG1GC -XX:G1HeapRegionSize=8 -XX:ConcGCThreads=1 -XX:InitiatingHeapOccupancyPercent=45",
        "4": "-Djava.security.egd=file:/dev/./urandom -DLog4j2.contextSelector=org.apache.logging.log4j.core.async.AsyncLoggerContextSelector -Dmicro.service.shutdown.wait.time=15000 -Dmicro.service.shutdown.auto.wait=false -server -Xms2560m -Xmx2560m -Xss1m -XX:MetaspaceSize=512m -XX:MaxMetaspaceSize=512m -XX:ParallelGCThreads=${env.CPU_LIMIT} -XX:+UseG1GC -XX:G1HeapRegionSize=8 -XX:ConcGCThreads=1 -XX:InitiatingHeapOccupancyPercent=45",
        "8": "-Djava.security.egd=file:/dev/./urandom -DLog4j2.contextSelector=org.apache.logging.log4j.core.async.AsyncLoggerContextSelector -Dmicro.service.shutdown.wait.time=15000 -Dmicro.service.shutdown.auto.wait=false -server -Xms4096m -Xmx4096m -Xss1m -XX:MetaspaceSize=512m -XX:MaxMetaspaceSize=512m -XX:ParallelGCThreads=${env.CPU_LIMIT} -XX:+UseG1GC -XX:G1HeapRegionSize=8 -XX:ConcGCThreads=1 -XX:InitiatingHeapOccupancyPercent=45",
        "16": "-Djava.security.egd=file:/dev/./urandom -DLog4j2.contextSelector=org.apache.logging.log4j.core.async.AsyncLoggerContextSelector -Dmicro.service.shutdown.wait.time=15000 -Dmicro.service.shutdown.auto.wait=false -server -Xms10240m -Xmx10240m -Xss1m -XX:MetaspaceSize=512m -XX:MaxMetaspaceSize=512m -XX:ParallelGCThreads=${env.CPU_LIMIT} -XX:+UseG1GC -XX:G1HeapRegionSize=8 -XX:ConcGCThreads=1 -XX:InitiatingHeapOccupancyPercent=45"
    ]

    jvm_opts = map_jvm_opts."${env.MEM_LIMIT}"
    return jvm_opts
}

def getAppOpts() {
    app_opts = ''
    return app_opts
}