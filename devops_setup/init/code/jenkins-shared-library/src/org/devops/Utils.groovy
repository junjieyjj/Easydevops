#!groovy
package org.devops

/**
* @author:  John.Yu
* @description: 获取项目参数并进行参数检查
* @return: Map
*/
def getProjectParams(String jobType, Map config) {
    def log = new Log()

    log.info ("==========初始化入参 & 参数检查==========")
    // 将参数值统一转换为小写，避免后续因大小写匹配错误
    config.each {
        if (it.key ==~ /^(?!DOCKER_FILE|HELM_TEMPLATE).*$/) {
            config.put(it.key, it.value.toLowerCase())
        }
    }

    // 进入CI参数判断流程
    if ( jobType.toUpperCase() == 'CI' ) {
        // GitUrl地址解析断言
        // 待补全
        assert (config.GIT_REPO && (config.GIT_REPO != null)): "ERROR: 键不存在或值为空"

        // 代码类型检查
        assert (config.CODE_TYPE && (config.CODE_TYPE != null)): "ERROR: 键不存在或值为空"
        assert config?.CODE_TYPE ==~ /java|go|nodejs|html|php/: "ERROR: CODE_TYPE代码类型不在允许的列表中"

        // 构建类型检查
        assert (config.BUILD_TYPE && (config.BUILD_TYPE != null)): "ERROR: 键不存在或值为空"
        assert config?.BUILD_TYPE ==~ /maven|npm|none/: "ERROR: BUILD_TYPE构建类型不在允许的列表中"

        // NODEJS_VER赋值与版本判断
        if (config.BUILD_TYPE?.contains("npm")) {
            config?.NODEJS_VER = config.NODEJS_VER ?: '10'
            config?.remove('MAVEN_TYPE')
            assert config?.NODEJS_VER ==~ /6|8|10|12|14/: "ERROR: NODEJS版本不在允许的列表中"
        }

        // MAVEN_TYPE赋值
        if (config.BUILD_TYPE?.contains("maven")) {
            config?.MAVEN_TYPE = config.MAVEN_TYPE ?: 'maven_package'
            assert config?.MAVEN_TYPE ==~ /maven_package|maven_deploy|maven_multi_module_package|maven_multi_module_deploy/: "ERROR: MAVEN构建类型不在允许的列表中"
        }

        // DOCKER_BUILD：根据MAVEN_TYPE内容控制是否开启
        //if ( config.MAVEN_TYPE?.contains("deploy") ) {
        //    config.DOCKER_BUILD = "false"
        //    config?.remove('DOCKER_FILE')
        //} else {
        //    config.DOCKER_BUILD = "true"
        //}

        // ARTIFACT_TYPE：根据MAVEN_TYPE内容控制是否开启
        if (config?.ARTIFACT_TYPE == 'file') {
            config?.remove('DOCKER_FILE')
        }

        if (config.MAVEN_TYPE?.contains("deploy")) {
            config.ARTIFACT_TYPE = "null"
            config?.remove('DOCKER_FILE')
        } else {
            config.ARTIFACT_TYPE = config.ARTIFACT_TYPE ?: 'image'
        }

        // DOCKER_FILE：MAVEN_TYPE不包含deploy或DOCKER_BUILD==true时获取DOCKER_FILE值
        if (config?.MAVEN_TYPE ==~ /^(?!deploy).*$/ && config.ARTIFACT_TYPE == "image") {
            config.DOCKER_FILE = config.DOCKER_FILE ?: 'null'
            assert config.DOCKER_FILE != 'null': "ERROR: DOCKER_FILE不能为空，请指定Dockerfile文件"
        }

    }

    // 进入CD参数判断流程
    if ( jobType.toUpperCase() == 'CD' ) {
        // HELM_TEMPLATE
        if ( config.DEPLOY_TYPE in ["k8s", "k8s_helm3"] ) {
            assert (config.HELM_TEMPLATE && (config.HELM_TEMPLATE != 'null')): "ERROR: 键不存在或值为空"
            assert config?.HELM_TEMPLATE ==~ /General|GoLang|EKSBackendJava/: "ERROR: HELM_TEMPLATE构建类型不在允许的列表中"
            //config.HELM_TEMPLATE = config.HELM_TEMPLATE ?: 'null'
            //assert config.HELM_TEMPLATE != 'null' : "ERROR: HELM_TEMPLATE不能为空，请指定Helm模板"
        }
    }

    // 打印初始化参数
    config.each {
        println(it.key + ": " + it.value)
    }

    log.info ("==========初始化入参 & 参数检查==========")
    
    return config
}



