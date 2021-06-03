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
    def dockerUtils = new org.devops.docker.Utils()

    // 获取项目信息（添加全局环境变量：PROJECT_GROUP_NAME、PROJECT_NAME）
    jenkins.getProjectInfo()
    // 获取项目参数并进行初始化处理和校验
    Map METADATA = utils.getProjectParams('CI', config)

    // 获取全局配置（自定义的黑白名单之类）
    //getGlobalConfig()

    pipeline {
        agent {
            kubernetes {
                yaml podtemlateCI()
            }
        }
        options {
            timestamps()                // Console开启时间显示
            disableConcurrentBuilds()   // 禁止管道并发运行
            //skipDefaultCheckout()       // 禁止pipeline段默认在工作空间签出SCM
            ansiColor('xterm')          // 控制台输出增加颜色支持
            gitLabConnection('Gitlab')  // 指定GitLab连接实例
        }
        environment {
            GIT_CREDENTIAL_ID = 'gitlab-ssh-key'
            DOCKER_REGISTRY_HOST = "216059448262.dkr.ecr.ap-east-1.amazonaws.com"
            DOCKER_REGISTRY_CREDENTIAL_ID = 'aws-registry-secret'
            //DOCKER_REGISTRY_HOST = "636957932458.dkr.ecr.ap-east-1.amazonaws.com"
            //DOCKER_REGISTRY_CREDENTIAL_ID = "aws"
        }
        // 参数配置已由SeedJob_Pipeline创建
        // parameters {
        //     choice(name: 'BRANCH', choices: ['master', 'stag', 'dev'], description: '选择构建分支')
        // }
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
                        dir("src_code") {
                            metric {
                                // Git代码签出
                                tools.checkoutSource(METADATA.GIT_REPO, env.BRANCH, env.GIT_CREDENTIAL_ID)
                                // 设置Job构建显示名称
                                env.BUILD_TAG = jenkins.setJobDisplayName()
                                // 设置Job描述信息
                                jenkins.setJobDesc('CI')
                                // 上传流水线状态
                                tools.gitlabCommitStatusPush { }
                            }
                        }
                    }
                }
            }

            stage("Build_Src") {
                steps {
                    script{
                        dir("src_code") {
                            metric {
                                tools.gitlabCommitStatusPush {
                                    // 构建应用
                                    tools.build(METADATA)
                                }
                            }
                        }
                    }
                }
            }

            stage("Unit_Test") {
                steps {
                    script{
                        dir("src_code") {
                            metric {
                                tools.gitlabCommitStatusPush {
                                    // 构建应用
                                    tools.unitTest(METADATA)
                                }
                            }
                        }
                    }
                }
            }

            stage("Coverage") {
                steps {
                    script{
                        dir("src_code") {
                            metric {
                                tools.gitlabCommitStatusPush {
                                    // 构建应用
                                    tools.coverage(METADATA)
                                }
                            }
                        }
                    }
                }
            }

            stage("Sonar_Scan") {
                steps {
                    script{
                        dir("src_code") {
                            metric {
                                tools.gitlabCommitStatusPush {
                                    // 构建应用
                                    tools.sonarScan(METADATA)
                                }
                            }
                        }
                    }
                }
            }

            stage("Build_Images") {
                when { equals expected: "image", actual: METADATA.ARTIFACT_TYPE }
                steps {
                    script{
                        dir("src_code") {
                            metric {
                                 tools.gitlabCommitStatusPush {
                                    // 登录Docker镜像仓库
                                    dockerUtils.dockerLoginRegistry(env.DOCKER_REGISTRY_HOST, env.DOCKER_REGISTRY_CREDENTIAL_ID)
                                    // 镜像构建
                                    dockerUtils.dockerBuild(METADATA.DOCKER_FILE)
                                    // 镜像推送
                                    dockerUtils.dockerPush(env.DOCKER_REGISTRY_HOST)
                                }
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