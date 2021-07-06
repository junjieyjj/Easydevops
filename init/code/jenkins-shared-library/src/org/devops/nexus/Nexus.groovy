package org.devops.nexus
import org.devops.Log

// 构建应用-上传制品文件
def pushArtifactFile(Map METADATA, String nexusCscredentialsId, String nexusUrl, String nexusCustomRepository) {
    def log = new Log()
    String projectGroupName = "${env.PROJECT_GROUP_NAME}"
    String projectName = "${env.PROJECT_NAME}"
    String buildTag = "${env.BUILD_TAG}"
    String artifactFile = "${env.ARTIFACT_FILE}"
    String artifactFileSuffix = "${env.ARTIFACT_FILE_SUFFIX}"

    if ( METADATA.ARTIFACT_TYPE == 'file'){
        withCredentials([usernamePassword(credentialsId: nexusCscredentialsId, usernameVariable: 'nexusUser', passwordVariable: 'nexusPassword')]) {
            String MD5 = sh ( script:"set +x && md5sum ${artifactFile}", returnStdout: true ).trim()
            log.info ("开始上传制品文件")
            log.info ("源文件地址：${artifactFile}")
            log.info ("源文件MD5：" + "${MD5}".tokenize(' ')[0])
            log.info ("目标路径：${nexusUrl}/repository/${nexusCustomRepository}/${projectGroupName}/${projectName}/${buildTag}.${artifactFileSuffix} ")
            log.info ("上传制品文件……")

            try {
                uploadResponseCode = sh ( script:"""
                    set +x
                    curl -IL -o /dev/null -s -w %{http_code} \
                    --user "${nexusUser}:${nexusPassword}" \
                    --upload-file ${artifactFile} \
                    ${nexusUrl}/repository/${nexusCustomRepository}/${projectGroupName}/${projectName}/${buildTag}.${artifactFileSuffix}
                """, returnStdout: true ).trim()
            }
            catch (any) {
                uploadResponseCode = '999'
            }
            finally {
                switch("${uploadResponseCode}")
                {
                    case '201':
                        log.done ("上传制品文件成功")
                        break

                    default:
                        log.error ("上传制品失败，异常退出。")
                        sh "exit 1"
                }
            }
        }
    }
}

// 上传制品依赖jar
def deployToNexus(Map METADATA, String nexusCscredentialsId, String nexusUrl, String nexusCustomRepository) {
    maven_snapshots_repository = env.MAVEN_SNAPSHOTS_REPOSITORY ?: 'maven-snapshots'
    maven_release_repository = env.MAVEN_RELEASES_REPOSITORY ?: 'maven-releases'
    repository_message = """
    ${nexusUrl}/repository/${maven_snapshots_repository}
    ${nexusUrl}/repository/${maven_release_repository}
    """
    log.info ("开始执行mvn deploy上传")
    log.info ("目标路径：${repository_message}")

    if (METADATA.MAVEN_TYPE == 'maven_multi_module_package') {
        withCredentials([usernamePassword(credentialsId: nexusCscredentialsId, usernameVariable: 'nexusUser', passwordVariable: 'nexusPassword')]) {
            sh "mvn deploy -Dmaven.test.skip=true -DaltSnapshotDeploymentRepository=${maven_snapshots_repository}::default::http://nexus-hk.intranet.local/repository/amway-snapshots -DaltReleaseDeploymentRepository=${maven_release_repository}::default::${nexusUrl}/repository/${maven_release_repository}"
        }
    }
    else {
        log.info ("不需要执行mvn deploy")
    }
}