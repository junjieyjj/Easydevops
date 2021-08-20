#!groovy
package org.devops
import org.devops.deploy.K8s
import groovy.io.FileType

// Git代码迁出
def checkoutSource( String repoUrl, String branch, String gitCredentialsId ){
    def log = new Log()
    def jenkins = new Jenkins()

    log.info ("仓库地址: ${repoUrl}, 分支名称: ${branch}")
    Map scmVars = checkout([
        $class: 'GitSCM',
        userRemoteConfigs: [[url: repoUrl, credentialsId: gitCredentialsId]],
        branches: [[name: branch]],
        extensions: [[$class: 'CheckoutOption', timeout: 30], [$class: 'CleanBeforeCheckout', deleteUntrackedNestedRepositories: true]],
        submoduleCfg: [],
        doGenerateSubmoduleConfigurations: false
        ])
    println scmVars

    // 获取GIT_PROJECT_ID（取url中路径段）
    gitUrl = scmVars.GIT_URL
    if(gitUrl.indexOf('git@') >= 0) {
        // 如果是git@格式，转换为http格式
        gitUrl = 'http://' + gitUrl.split('@')[1].replaceAll(':','/')
    }
    URL gitUrl = new URL(gitUrl)
    env.GIT_PROJECT_ID = gitUrl.getPath().replace(".git","").substring(1)

    // 获取GIT_COMMIT
    // env.GIT_COMMIT_LONG = sh ( script:'git rev-parse HEAD', returnStdout: true ).trim()
    env.GIT_COMMIT_LONG = scmVars.GIT_COMMIT
    env.GIT_COMMIT_SHORT = scmVars.GIT_COMMIT.substring(0,8)
    env.GIT_BRANCH_NAME = scmVars.GIT_BRANCH.replace("origin/","")

    println """
    ***INFO：Add checkout metadata to the global environment variable
    ***INFO：GIT_PROJECT_ID：${env.GIT_PROJECT_ID}
    ***INFO：GIT_BRANCH_NAME：${env.BRANCH}
    ***INFO：GIT_COMMIT_LONG：${env.GIT_COMMIT_LONG}
    ***INFO：GIT_COMMIT_SHORT：${env.GIT_COMMIT_SHORT}
    """.stripIndent()

    // 获取当前路径与列出目录文件
    sh '''
        set +x
        echo ***INFO：当前目录路径：$(pwd)
        echo ***INFO：当前目录大小：$(du -hd0 | awk '{print $1}')
        echo -e ***INFO：列出当前目录文件 \n ls -lha --time-style=long-iso | tail -n +2
       '''
}

// 上传GitLab Commit状态（Pipeline状态）(块调用)
def gitlabCommitStatusPush(Closure body) {
    gitlabCommitStatus(
        name: env.STAGE_NAME,
        builds: [[projectId: env.GIT_PROJECT_ID, revisionHash: env.GIT_COMMIT_LONG]])
        {
            body()
        }
}

// 构建应用-查找制品文件
@NonCPS
def getArtifactFile(Map METADATA) {
    // 遍历target目录查找制品文件
    println "***INFO：./target目录下查找构建制品文件"
    String currentPath = env.WORKSPACE + '/src_code'
    def targetPath = new File( currentPath + '/target' )
    echo "${targetPath}"
    sh "ls ${targetPath}"
    if( targetPath.exists() ) {
        int count=0
        // 当前目录递归查找文件
        targetPath.traverse( type:FileType.FILES, maxDepth: 0, nameFilter:~/.*\.war|.*\.jar/ ) { file->
            count++
            println (file.toString())
            artifact_file = file.toString()
        }

        // 找到大于两个制品文件，报错
        if ( count >= 2 ) { 
            println "***ERROR：找到多个构建制品文件，正常应只有一个文件，异常中断退出。"
            sh 'exit 1'
        }

        // 没找到制品文件，报错
        if ( count == 0 ) {
            println "***ERROR：找不到构建制品文件，异常中断退出。"
            sh 'exit 1'
        }

        // 找到一个制品文件，且制品类型为file的话就将制品文件信息添加到全局环境变量
        if ( count == 1 && METADATA.ARTIFACT_TYPE == 'file' ) {
            env.ARTIFACT_FILE = artifact_file
            env.ARTIFACT_FILE_SUFFIX = artifact_file.tokenize('.')[-1]

            println """
            ***INFO：Add artifact metadata to the global environment variable
            ***INFO：ARTIFACT_FILE：${env.ARTIFACT_FILE}
            ***INFO：ARTIFACT_FILE_SUFFIX：${env.ARTIFACT_FILE_SUFFIX}
            """.stripIndent()
        }
    } else {
        println "***ERROR：不存在./target目录，异常中断退出。"
        sh 'exit 1'
    }
}

// 构建应用
def build(Map METADATA) {
    def log = new Log()
    def nexus = new org.devops.nexus.Nexus()

    switch( METADATA.BUILD_TYPE )
      {
        case "none":
          println "***INFO：前端静态页面不需要构建。"
          break

        case "npm":
          // 判断后抛出
          //log.info ("当前NODEJS_VER未指定，默认使用版本为“10”")

          sh "node -v && npm -v"
          sh "npm config set registry https://registry.npm.taobao.org --global"
          sh "npm config set disturl https://npm.taobao.org/dist --global"
          sh "npm install -g umi"
          sh "npm install umi-plugin-react --save-dev"
          sh "umi build"
          break

        case "go":
          sh """
              set +x && CGO_ENABLED=0 GOOS=linux GOARCH=amd64 && go build -o ./target/run
              echo ***INFO：当前目录是 `pwd` && echo ***INFO：列出target目录文件 && ls -lha --time-style=long-iso ./target/
            """
          break

        case "maven":
            // 加载shared-libraries resources资源到当前目录
            def mvn_settings = libraryResource 'maven_settings/mvn_default_settings.xml'
            writeFile text: mvn_settings, file: "./mvn_settings.xml", encoding: "UTF-8"

            // maven_package
            if ( METADATA.MAVEN_TYPE == 'maven_package'  ) {
                log.info ("开始构建应用程序")
                log.info ("BUILD_TYPE：${METADATA.BUILD_TYPE}")
                log.info ("MAVEN_TYPE：${METADATA.MAVEN_TYPE}")

                sh 'mvn -T 1C -e -B -U -s ./mvn_settings.xml -Dmaven.test.skip=true clean package'

                // 查找制品文件
                getArtifactFile (METADATA)

                // 上传制品文件
                nexus.pushArtifactFile (METADATA, 'nexus3_admin', 'http://11.0.0.201:8081/nexus', 'ci-artifact')
            }

            // maven_deploy
            if ( METADATA.MAVEN_TYPE == 'maven_deploy'  ) {
                sh '''
                set +x
                echo 待支持
                exit 1
                '''
            }

            // maven_multi_module_package
            if ( METADATA.MAVEN_TYPE == 'maven_multi_module_package'  ) {
                sh '''
                set +x
                echo 待支持
                exit 1
                '''
            }

            // maven_multi_module_deploy
            if ( METADATA.MAVEN_TYPE == 'maven_multi_module_deploy'  ) {
                sh '''
                set +x
                echo 待支持
                exit 1
                '''
            }
          break

        default:
          echo "***ERROR：构建类型不在支持列表中，异常退出。"
          sh "exit 1"
      }
}

// 单元测试
def unitTest(Map METADATA) {
    def log = new Log()
    def nexus = new org.devops.nexus.Nexus()

    switch( METADATA.BUILD_TYPE )
      {
        case "none":
          println "***INFO：前端静态页面不需要单元测试。"
          break

        case "npm":
          // 判断后抛出
          //log.info ("当前NODEJS_VER未指定，默认使用版本为“10”")

            sh '''
            set +x
            echo 待支持
            exit 1
            '''
          break

        case "go":
            sh '''
            set +x
            echo 待支持
            exit 1
            '''
          break

        case "maven":
            // 加载shared-libraries resources资源到当前目录
            def mvn_settings = libraryResource 'maven_settings/mvn_default_settings.xml'
            writeFile text: mvn_settings, file: "./mvn_settings.xml", encoding: "UTF-8"

            // maven_package
            if ( METADATA.MAVEN_TYPE == 'maven_package'  ) {
                log.info ("开始执行单元测试")
                log.info ("BUILD_TYPE：${METADATA.BUILD_TYPE}")
                log.info ("MAVEN_TYPE：${METADATA.MAVEN_TYPE}")

                sh 'mvn -T 1C -e -B -U -s ./mvn_settings.xml org.jacoco:jacoco-maven-plugin:prepare-agent test -Dmaven.test.failure.ignore=true'
                try {
                    junit '**/target/**/surefire-reports/*.xml'
                } catch (Exception e) {
                    println('***INFO：' + e.getMessage())
                }
            }

            // maven_deploy
            if ( METADATA.MAVEN_TYPE == 'maven_deploy'  ) {
                sh '''
                set +x
                echo 待支持
                exit 1
                '''
            }

            // maven_multi_module_package
            if ( METADATA.MAVEN_TYPE == 'maven_multi_module_package'  ) {
                sh '''
                set +x
                echo 待支持
                exit 1
                '''
            }

            // maven_multi_module_deploy
            if ( METADATA.MAVEN_TYPE == 'maven_multi_module_deploy'  ) {
                sh '''
                set +x
                echo 待支持
                exit 1
                '''
            }
          break

        default:
          echo "***ERROR：构建类型不在支持列表中，异常退出。"
          sh "exit 1"
      }
}

// 覆盖率统计
def coverage(Map METADATA) {
    def log = new Log()
    def nexus = new org.devops.nexus.Nexus()

    switch( METADATA.BUILD_TYPE )
      {
        case "none":
          println "***INFO：前端静态页面不需要统计覆盖率。"
          break

        case "npm":
          // 判断后抛出
          //log.info ("当前NODEJS_VER未指定，默认使用版本为“10”")

            sh '''
            set +x
            echo 待支持
            exit 1
            '''
          break

        case "go":
            sh '''
            set +x
            echo 待支持
            exit 1
            '''
          break

        case "maven":
            // 加载shared-libraries resources资源到当前目录
            def mvn_settings = libraryResource 'maven_settings/mvn_default_settings.xml'
            writeFile text: mvn_settings, file: "./mvn_settings.xml", encoding: "UTF-8"

            // maven_package
            if ( METADATA.MAVEN_TYPE == 'maven_package'  ) {
                log.info ("开始执行覆盖率统计，阈值：${env.JACOCO_COVERAGE_NUM}%")
                log.info ("BUILD_TYPE：${METADATA.BUILD_TYPE}")
                log.info ("MAVEN_TYPE：${METADATA.MAVEN_TYPE}")

                jacoco(
                    execPattern: 'target/jacoco.exec',
                    changeBuildStatus: true, 
                    maximumLineCoverage: "${env.JACOCO_COVERAGE_NUM}",
                    minimumLineCoverage: "${env.JACOCO_COVERAGE_NUM}"
                )
            }

            // maven_deploy
            if ( METADATA.MAVEN_TYPE == 'maven_deploy'  ) {
                sh '''
                set +x
                echo 待支持
                exit 1
                '''
            }

            // maven_multi_module_package
            if ( METADATA.MAVEN_TYPE == 'maven_multi_module_package'  ) {
                sh '''
                set +x
                echo 待支持
                exit 1
                '''
            }

            // maven_multi_module_deploy
            if ( METADATA.MAVEN_TYPE == 'maven_multi_module_deploy'  ) {
                sh '''
                set +x
                echo 待支持
                exit 1
                '''
            }
          break

        default:
          echo "***ERROR：构建类型不在支持列表中，异常退出。"
          sh "exit 1"
      }
}

// 代码扫描
def runQualityGate() {
    timeout(time: 1, unit: 'HOURS') {
        def qg = waitForQualityGate()
        if (qg.status != 'OK') {
            println "***ERROR： 代码未能通过质量门禁: ${qg.status}"
        }
    }
}

def sonarScan(Map METADATA) {
    // 定义质量门禁
    def log = new Log()
    def nexus = new org.devops.nexus.Nexus()

    switch( METADATA.BUILD_TYPE )
      {
        case "none":
          println "***INFO：前端静态页面不需要代码扫描。"
          break

        case "npm":
          // 判断后抛出
          //log.info ("当前NODEJS_VER未指定，默认使用版本为“10”")

            sh '''
            set +x
            echo 待支持
            exit 1
            '''
          break

        case "go":
            sh '''
            set +x
            echo 待支持
            exit 1
            '''
          break

        case "maven":
            // 加载shared-libraries resources资源到当前目录
            def mvn_settings = libraryResource 'maven_settings/mvn_default_settings.xml'
            writeFile text: mvn_settings, file: "./mvn_settings.xml", encoding: "UTF-8"

            // 导入sonarqube环境配置
            withSonarQubeEnv('sonarqube') { 
                sh "mvn -s ./mvn_settings.xml -Dmaven.test.skip=true org.sonarsource.scanner.maven:sonar-maven-plugin:3.7.0.1746:sonar -Dsonar.projectKey=${env.PROJECT_GROUP_NAME}-${env.PROJECT_NAME} -Dsonar.projectName=${env.PROJECT_GROUP_NAME}-${env.PROJECT_NAME}"
            }
            runQualityGate()

            // maven_deploy
            if ( METADATA.MAVEN_TYPE == 'maven_deploy'  ) {
                sh '''
                set +x
                echo 待支持
                exit 1
                '''
            }

            // maven_multi_module_package
            if ( METADATA.MAVEN_TYPE == 'maven_multi_module_package'  ) {
                sh '''
                set +x
                echo 待支持
                exit 1
                '''
            }

            // maven_multi_module_deploy
            if ( METADATA.MAVEN_TYPE == 'maven_multi_module_deploy'  ) {
                sh '''
                set +x
                echo 待支持
                exit 1
                '''
            }
          break

        default:
          echo "***ERROR：构建类型不在支持列表中，异常退出。"
          sh "exit 1"
      }
}


// 发布方法入口（发布类型判断）
def deploy(Map METADATA) {
    def log = new Log()
    def k8s = new K8s()

    log.info ("==========应用发布==========")
    switch( METADATA.DEPLOY_TYPE )
    {
        case "k8s":
            k8s(METADATA)
            break

        case "k8s_helm3":
            break

        default:
            echo "***ERROR：发布类型不在支持列表中，异常退出。"
            sh "exit 1"
    }
    log.info ("==========应用发布==========")
}