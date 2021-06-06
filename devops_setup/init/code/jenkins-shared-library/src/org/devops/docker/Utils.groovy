package org.devops.docker
import org.devops.aws.ECR

// 登录Docker镜像仓库
def dockerLoginRegistry(String registryUrl, String registryCredentialId) {
    if ( registryUrl =~ 'amazonaws.com' ) {
        println ("***INFO：当前为AWS Docker Registry")
        withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: registryCredentialId, accessKeyVariable: 'AWS_ACCESS_KEY_ID', secretKeyVariable: 'AWS_SECRET_ACCESS_KEY']]) {
            String region = registryUrl.tokenize('.')[-3].toLowerCase()
            String repoName = "${env.PROJECT_GROUP_NAME}/${env.PROJECT_NAME}"

            // 创建镜像仓库并获取ecrToken
            def ecr = new ECR()
            ecrToken = ecr.createRepository(AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, region, "${repoName}")

            // 登录镜像仓库
            sh """
                set +x
                echo ***INFO：登陆远程镜像仓库
                docker login -u ${ecrToken[0]} -p ${ecrToken[1]} ${registryUrl}
            """
        }
    } else {
        println ("***INFO：当前为普通Docker Registry")
        withCredentials([usernamePassword(credentialsId: registryCredentialId, usernameVariable: 'dockerUser', passwordVariable: 'dockerPassword')]) {
            sh """
                set +x
                echo ***INFO：登陆远程镜像仓库
                docker login -u ${dockerUser} -p ${dockerPassword} ${registryUrl}
            """
        }
    }
}

// 镜像构建
def dockerBuild(String dockerFile) {
    String workspace = "${env.WORKSPACE}"
    String projectName = "${env.PROJECT_NAME}"
    String buildTag = "${env.BUILD_TAG}"
    String gitCommitLong = "${env.GIT_COMMIT_LONG}"

    // 创建Docker忽略文件
    writeFile file: "./.dockerignore", text: """\
    **/Dockerfile
    **/.git
    **/.dockerignore
    """.stripIndent()

    /**
     def file = new File("${env.WORKSPACE}/DockerFiles/${dockerfile}")
     if( file.exists() ) {
     println "文件存在"
     }
     else {
     println "文件不存在"
     }


     json_file = "${env.WORKSPACE}/testdata/test_json.json"
     if(fileExists(json_file) == true) {
     echo("json file is exists")
     }else {
     error("here haven't find json file")
     }
     **/

    // 复制对应的DockerFile到当前应用目录下
    sh """
        set +x && echo ***INFO：复制Dockerfile文件到当前应用目录
        set -x && /bin/cp -f ${workspace}/DockerFiles/${dockerFile} ./Dockerfile
        set +x && echo ***INFO：构建Docker镜像
        set -x && docker build -t ${projectName}:${buildTag} --build-arg git_hash=${gitCommitLong} ./
    """
}

// 镜像打标签、推送
def dockerPush(String registryUrl) {
    String projectGroupName = "${env.PROJECT_GROUP_NAME}"
    String projectName = "${env.PROJECT_NAME}"
    String buildTag = "${env.BUILD_TAG}"

    sh """
        set +x && echo ***INFO：镜像打Tag
        set -x && docker tag ${projectName}:${buildTag} ${registryUrl}/${projectGroupName}/${projectName}:${buildTag}
        set +x && echo ***INFO：推送镜像到远程仓库
        set -x && docker push ${registryUrl}/${projectGroupName}/${projectName}:${buildTag}
    """
}

// 镜像拉取、打标签
def docker_Pull_Tag_Push(String srcRegistry, String destRegistry) {
    String projectName = "${env.PROJECT_NAME}"
    String buildTag = "${env.BUILD_TAG}"

    sh """
        set +x && echo ***INFO：从本地镜像仓库拉取镜像
        set -x && docker pull ${srcRegistry}/${projectName}:${buildTag}

        set +x && echo ***INFO：镜像打TAG
        set -x && docker tag ${srcRegistry}/${projectName}:${buildTag} ${destRegistry}/${projectName}:${buildTag}
    """
}

