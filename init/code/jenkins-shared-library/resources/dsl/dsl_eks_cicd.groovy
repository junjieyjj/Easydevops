import java.io.File 

/* 从参数获取jobs */
String gitlab_fqdn = props['gitlab_fqdn']
Map jobs_map = props['jobs_map']
ArrayList ci_branch_list = props['ci_branch_list']

/* 遍历jobs，批量创建Jenkins cicd job */
jobs_map.each { it ->
  group = it.key

  /* 创建group文件夹 */
  folder(group) {
    description '创建项目组文件夹'
  }

  (it.value).each{ project_map ->
    project = project_map."NAME"
    group_project = group + "-" + project
    base_path = group + '/' + project
    git_repo = project_map."GIT_REPO"
    config_git_repo = git_repo.split('.git')[0] + '-config.git'
    deploy_env = project_map."DEPLOY_ENV" ? project_map."DEPLOY_ENV" : ['qa','pd']
    replicas = project_map."REPLICA_COUNT" ? project_map."REPLICA_COUNT" : [1,2,3,4]
    cpu = project_map."CPU" ? project_map."CPU" : [1,2,4,8]
    mem = project_map."MEM" ? project_map."MEM" : [1,4,8,16]
    ci_create = project_map."CI_CREATE" ?: 'false'
    cd_create = project_map."CD_CREATE" ?: 'false'
    configmap_conf = project_map."CONFIGMAP_CONF" ? project_map."CONFIGMAP_CONF" : 'false'
    secret_env = project_map."SECRET_ENV" ? project_map."SECRET_ENV" : 'false'

    /* 创建group/project文件夹 */
    folder(group + '/' + project) {
      description '创建项目文件夹'
    }
    /* 遍历branch列表，创建多个ci */
    if (ci_create == "true") {
      String ci_job_name = 'ci_' + group + '_' + project
      pipelineJob("$base_path/" + ci_job_name) {
        description("${project} ci pipeline")
        keepDependencies(false)
        parameters {
          choiceParam("BRANCH", ci_branch_list, "选择构建分支")
        }
        /* 使用genericTrigger插件 */
        triggers {
            genericTrigger {
                genericVariables {
                    genericVariable {                // 获取分支名
                    key('object_kind')
                    value('$.object_kind')
                    expressionType('JSONPath')
                    }
                    genericVariable {                // 获取分支名
                    key('branch')
                    value('$.ref')
                    expressionType('JSONPath')
                    regexpFilter('refs/heads/')      // 字符串过滤，会删掉匹配字符串
                    }
                    genericVariable {                // 获取Git Commit
                    key("commit")
                    value('$.checkout_sha')
                    expressionType('JSONPath')
                    }
                    genericVariable {                // 获取Git用户ID
                    key("user_username")
                    value('$.user_username')
                    expressionType('JSONPath')
                    }
                    genericVariable {                // 获取Git用户名称
                    key("user_name")
                    value('$.user_name')
                    expressionType('JSONPath')
                    }
                }
                token("${group_project}")            // Token使用group-project
                silentResponse(false)                // false|true
                printPostContent(false)              // false|true，是否打印POST内容，用于调试
                printContributedVariables(false)     // false|true，是否打印本插件定义的变量
                regexpFilterText('${$object_kind}_${branch}')                             // 从上面定义的变量获取字符串
                regexpFilterExpression('^push_(dev.*|test.*|release.*|bugfix.*|hotfix.*|master)$')    // 正则表达式，只有字符串匹配才会触发Job
            }
        }


        definition {
          cpsScm {
            scm {
              git {
              remote {
                url("git@${gitlab_fqdn}:devops/cicd.git")
                credentials("gitlab-ssh-key")
              }
              branch("master")
              }
            }
          scriptPath("AppMetadata/${base_path}/CI_Jenkinsfile")
          }
        }
        disabled(false)
      }
    }

    if(project_map."DEPLOY_TYPE" == "k8s"){
      String configmap_conf_cd_job_name = 'config_' + group + '_' + project
      String secret_env_cd_job_name = 'secret_' + group + '_' + project
      String cd_job_name = 'cd_' + group + '_' + project

      /* 创建cd */
      if (cd_create == "true") {
        pipelineJob("$base_path/" + cd_job_name) {
          description("${project} cd pipeline")
          keepDependencies(false)
          parameters {
            choiceParam("ENV", deploy_env, "发布环境")
            runParam('BUILD_TAG', "${group}/${project}/ci_${group}_${project}", '选择CI版本', 'SUCCESSFUL')
            choiceParam("REPLICA_COUNT", replicas, "发布POD数量")
            choiceParam("CPU", cpu, "每个pod的最大cpu，1 = 1000m")
            choiceParam("MEM", mem, "每个pod的最大mem，1 = 1Gi")
          }
          definition {
            cpsScm {
              scm {
                git {
                remote {
                  url("git@${gitlab_fqdn}:devops/cicd.git")
                  credentials("gitlab-ssh-key")
                }
                branch("*/master")
                }
              }
            scriptPath("AppMetadata/${base_path}/CD_Jenkinsfile")
            }
          }
          disabled(false)

        }
      }

      /* 创建配置cd */
      if(configmap_conf == 'true'){
        /* 创建confmap cd */
        pipelineJob("$base_path/" + configmap_conf_cd_job_name) {
          description("${project} configmap conf cd pipeline")
          keepDependencies(false)
          parameters {
            choiceParam("ENV", deploy_env, "发布环境")
          }
          definition {
            cpsScm {
              scm {
                git {
                remote {
                  url("git@${gitlab_fqdn}:devops/cicd.git")
                  credentials("gitlab-ssh-key")
                }
                branch("*/master")
                }
              }
            scriptPath("AppMetadata/${base_path}/Config_Jenkinsfile")
            }
          }
          disabled(false)
        }
      }
      
      /* 创建秘钥cd */
      if(secret_env == 'true'){
        /* 创建secret cd */
        pipelineJob("$base_path/" + secret_env_cd_job_name) {
          description("${project} secret env cd pipeline")
          keepDependencies(false)
          parameters {
            choiceParam("ENV", deploy_env, "发布环境")
          }
          definition {
            cpsScm {
              scm {
                git {
                remote {
                  url("git@${gitlab_fqdn}:devops/cicd.git")
                  credentials("gitlab-ssh-key")
                }
                branch("*/master")
                }
              }
            scriptPath("AppMetadata/${base_path}/Secret_Jenkinsfile")
            }
          }
          disabled(false)
        }
      }

    }
  }
}



