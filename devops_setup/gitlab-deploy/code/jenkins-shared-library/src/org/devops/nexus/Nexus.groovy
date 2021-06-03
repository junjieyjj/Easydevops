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