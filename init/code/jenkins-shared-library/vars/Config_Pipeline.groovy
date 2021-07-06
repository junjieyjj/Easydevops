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
    def k8sUtils = new org.devops.kubernetes.Utils()

    // 获取项目信息（添加全局环境变量：PROJECT_GROUP_NAME、PROJECT_NAME）
    jenkins.getProjectInfo()
    // 获取项目参数并进行初始化处理和校验
    Map METADATA = utils.getProjectParams('CONFIG', config)

    // 获取全局配置（自定义的黑白名单之类）
    //getGlobalConfig()

    pipeline {
        agent any
        options { 
            timestamps()                // Console开启时间显示
            disableConcurrentBuilds()   // 禁止管道并发运行
            //skipDefaultCheckout()       // 禁止pipeline段默认在工作空间签出SCM
            ansiColor('xterm')          // 控制台输出增加颜色支持
            gitLabConnection('Gitlab')  // 指定GitLab连接实例
        }
        environment {
            GIT_CREDENTIAL_ID = 'gitlab_200_root'
            DOCKER_REGISTRY_HOST = "11.0.0.201:5000"
            DOCKER_REGISTRY_CREDENTIAL_ID = "registry_secret"

            // K8s KubeConfig凭证【Credentials（凭证）- Secret file（文件类型凭证）】
            KUBECONF_CREDENTIAL_ID = 'k8s-test-config'
            KUBECONF = credentials("${KUBECONF_CREDENTIAL_ID}")
        }
        parameters {
            choice(name: 'NAMESPACE', choices: ['prod', 'dev', 'test'], description: '选择发布环境')
        }
        triggers {
            GenericTrigger(
                genericVariables: [
                    // 获取事件类型（push、merge……）
                    [key: 'object_kind', value: '$.object_kind'],
                    // 获取分支名
                    [key: 'branch', value: '$.ref', regexpFilter: 'refs/heads/'],
                    // 获取GitCommit
                    [key: 'commit', value: '$.checkout_sha'],
                    // 获取Git用户ID
                    [key: 'user_username', value: '$.user_username'],
                    // 获取Git用户名称
                    [key: 'user_name', value: '$.user_name']
                ],
                // 触发过滤：定义从指定变量获取字符串用来提供过滤判断
                regexpFilterText: '$object_kind_$branch',
                // 触发过滤：只有从上面变量获取的字符串被该正则匹配成功才会触发
                regexpFilterExpression: '^push_(dev.*|test.*|release.*|master)$',

                // Token使用项目名称
                token: env.PROJECT_NAME,

                // false|true，静默响应，默认关闭，指触发请求调用Jenkins后是否响应结果
                silentResponse: false,
                // false|true，是否打印POST内容，用于调试
                printPostContent: false,
                // false|true，是否打印本插件定义的变量
                printContributedVariables: false

            )
        }

        stages  {
            stage("Checkout") {
                steps {
                    script{
                        metric {
                            // Git代码签出
                            tools.checkoutSource(METADATA.GIT_REPO, "master", env.GIT_CREDENTIAL_ID)
                            // 设置Job构建显示名称
                            env.BUILD_TAG = jenkins.setJobDisplayName()
                            // 设置Job描述信息
                            jenkins.setJobDesc('CONFIG')
                            // 设置触发用户
                            METADATA.TRIGGER_USER = user_username
                            // 上传流水线状态
                            tools.gitlabCommitStatusPush { }
                        }
                    }
                }
            }

            stage("Check_User") {
                steps {
                    script{
                        metric {
                            // 检查用户权限
                            tools.checkUser(METADATA)
                        }
                    }
                }
            }

            stage("Deploy") {
                steps {
                    script{
                        metric {
                            tools.gitlabCommitStatusPush{
                                // 创建命名空间
                                k8sUtils.createNamespace()
                                // 创建ConfigMap
                                k8sUtils.createConfigMapFromConfigFile()
                            }
                        }
                    }
                }
            }

        }

        post {
            failure {
                updateGitlabCommitStatus name: 'Checkoutx', state: 'failed'
            }
            success {
                updateGitlabCommitStatus name: 'Checkoutxx', state: 'success'
            }
        }
    }
}