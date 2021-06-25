#!groovy
import org.devops.*

def call(body) {
    def config = [:]
    body.resolveStrategy = Closure.DELEGATE_FIRST
    body.delegate = config
    body()

    // 实例化对象，导入共享库方法
    def utils = new Utils()
    def log = new Log()
    def jenkins = new Jenkins()
    def metric = new Metric()
    def tools = new Tools()

    // 获取项目信息（添加全局环境变量：PROJECT_GROUP_NAME、PROJECT_NAME）
    jenkins.getProjectInfo()
    // 获取项目参数并进行初始化处理和校验
    Map METADATA = utils.getProjectParams('CD', config)

    // 获取全局配置（自定义的黑白名单之类）
    //getGlobalConfig()

    pipeline {
        agent {
            kubernetes {
                yaml podtemlateCD()
            }
        }
        options { 
            timestamps()                // Console开启时间显示
            disableConcurrentBuilds()   // 禁止管道并发运行
            //skipDefaultCheckout()       // 禁止pipeline段默认在工作空间签出SCM
            ansiColor('xterm')          // 控制台输出增加颜色支持
        }
        environment {
            GIT_CREDENTIAL_ID = 'gitlab-ssh-key'

            // K8s KubeConfig凭证【Credentials（凭证）- Secret file（文件类型凭证）】
            AWS_ACCESS_KEY_ID="xxxxxxxxxxxxxxxxx"
            AWS_SECRET_ACCESS_KEY="xxxxxxxxxxxxxxxxx"
            AWS_DEFAULT_REGION="ap-east-1"
            KUBECONF_CREDENTIAL_ID = 'k8s-test-config'
            KUBECONF = credentials("${KUBECONF_CREDENTIAL_ID}")

            // CD_Jenkinsfile的GROUP_NAME作为kubernetes namespace
            NAMESPACE = "${PROJECT_GROUP_NAME}"
        }
        // 参数配置已由SeedJob_Pipeline创建
        // parameters {
        //     choice(name: 'ENV', choices: ['qa','pd'], description: '发布环境')
        //     choice(name: 'REPLICA_COUNT', choices: ['1','2','3','4'], description: '发布POD数量')
        //     choice(name: 'CPU', choices: ['1','2','4','8'], description: '每个pod的最大cpu，1 = 1000m    ')
        //     choice(name: 'MEM', choices: ['1','4','8','16'], description: '每个pod的最大mem，1 = 1Gi    ')
        //     run(name: 'BUILD_TAG', projectName: "${env.PROJECT_GROUP_NAME}/${env.PROJECT_NAME}/ci_${env.PROJECT_GROUP_NAME}_${env.PROJECT_NAME}", description: '选择CI版本', filter: 'SUCCESSFUL')
        // }

        stages  {
            stage("Pre Check") {
                steps {
                    script{
                        sh 'printenv'
                        // 设置Job构建显示名称
                        jenkins.setJobDisplayName('CD')
                        // 设置Job描述信息
                        jenkins.setJobDesc('CD')
                        // 从运行时参数获取名称作为BUILD_TAG全局变量
                        env.BUILD_TAG = env.BUILD_TAG_NAME
                        // 将BUILD_NUMBER作为VERSION
                        env.VERSION = env.BUILD_NUMBER

                        metric {
                            println ("BUILD_TAG: " + env.BUILD_TAG)
                            println ("VERSION: " + env.VERSION)
                            println ("PROJECT_GROUP_NAME: " + env.PROJECT_GROUP_NAME)
                            println ("PROJECT_NAME: " + env.PROJECT_NAME)
                            println ("ENV: " + env.ENV)
                        }
                    }
                }
            }

            stage("Deploy") {
                steps {
                    script{
                        metric {
                            tools.deploy(METADATA)
                        }
                    }
                }
            }

        }
    }
}