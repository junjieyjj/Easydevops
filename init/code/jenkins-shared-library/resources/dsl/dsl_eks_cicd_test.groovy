import java.io.File 

/* 从参数获取jobs */
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
    deploy_env = project_map."DEPLOY_ENV" ? project_map."DEPLOY_ENV" : ['qa','pt','pd']
    replicas = project_map."REPLICAS" ? project_map."REPLICAS" : [1,2,3,4]
    cpu = project_map."CPU" ? project_map."CPU" : [2,4,8]
    mem = project_map."MEM" ? project_map."MEM" : [4,8,16]
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
      ci_branch_list.each{ b ->
        String ci_job_name = 'ci_' + group + '_' + project
        pipelineJob("$base_path/" + ci_job_name + "-${b}" ) {
          description("${project} ci pipeline")
          keepDependencies(false)
          /* 使用genericTrigger插件 */
          triggers {
              genericTrigger {
                  genericVariables {
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
                  regexpFilterText('$branch')                             // 从上面定义的变量获取字符串
                  regexpFilterExpression('^' + b + '$')    // 正则表达式，只有字符串匹配才会触发Job
              }
          }

          definition {
            cpsScm {
              scm {
                git {
                remote {
                  url("git@gitlab-hk.intranet.local:devops/cicd.git")
                  credentials("gitlab-ssh-key")
                }
                branch("master")
                }
              }
            scriptPath("jobs/${base_path}/ci-jenkinsfile")
            }
          }
          disabled(false)
        }
      }
    }

    if(project_map."DEPLOY_TYPE" == "eks"){
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
            cascadeChoiceParameter {
              name("VERSION")
              description("发布版本")
              randomName("choice-parameter-5631314439613980")
              choiceType("PT_SINGLE_SELECT")
              referencedParameters("ENV")
              filterable(true)
              filterLength(1)
              script {
                groovyScript {
                  script {
                    script("""/* 根据选择的ENV参数，从Nexus拉取VERSION列表 */
                              def deploy_env = ENV
                              def group = "${group}".split("-test")[0]
                              def module = "${project}".replace('/','-').replace('_', '-').toLowerCase()
                              if (deploy_env in ['qa','preprod']){
                                  dir_prefix = ['dev']
                              }
                              else if (deploy_env in ['pt']){
                                  dir_prefix = ['master','dev','bugfix','adhoc']
                              }
                              else if (deploy_env in ['pd']){
                                  dir_prefix = ['master','bugfix','adhoc']
                              }
                              else {
                                  dir_prefix = ['']
                              }

                              res_version = []
                              res = []
                          
                              for (dp in dir_prefix) {
                                  def url = "curl -s  http://nexus-hk.intranet.local/service/rest/repository/browse/amway-pipeline-registery/" + dp + '/' + group + '/' + module + '/'
                                  def text = url.execute().text
                                  text.eachMatch('v[0-9]{14}-[0-9a-z]{8}-(dev|master|adhoc|bugfix){1}'){
                                      version = it[0]
                                      if (version in res){
                                          return
                                      }
                                      else{
                                          res.add(it[0])
                                      }
                                  }
                                  res_sort = res.reverse()
                                  def n = 0
                                  for (i in res_sort){
                                      res_version.add(i)
                                      n++
                                      if(n>49){
                                          break
                                      }
                                  }
                              }
                              
                              return res_version
                              """)
                    sandbox(false)
                    classpath {}
                    }
                    fallbackScript {
                    script('return[\'获取发布环境的版本列表失败，请检查CI是否执行成功\']')
                    sandbox(false)
                    classpath {}
                  }
                }
              }
            }

            choiceParam("REPLICAS", replicas, "发布POD数量")
            // cascadeChoiceParameter {
            //   name("REPLICAS")
            //   description("发布POD数量")
            //   randomName("choice-parameter-5631314439613981")
            //   choiceType("PT_SINGLE_SELECT")
            //   referencedParameters("ENV")
            //   filterable(true)
            //   filterLength(1)
            //   script {
            //     groovyScript {
            //       script {
            //         script("""return ["1","2","3","4"]""")
            //         sandbox(false)
            //         classpath {}
            //         }
            //         fallbackScript {
            //         script('return[\'获取REPLICAS参数列表失败\']')
            //         sandbox(false)
            //         classpath {}
            //       }
            //     }
            //   }
            // }
            choiceParam("CPU", cpu, "每个pod的最大cpu，1 = 1000m")
            // cascadeChoiceParameter {
            //   name("CPU")
            //   description("每个pod的最大cpu，1 = 1000m")
            //   randomName("choice-parameter-56313143215673981")
            //   choiceType("PT_SINGLE_SELECT")
            //   referencedParameters("ENV")
            //   filterLength(1)
            //   script {
            //     groovyScript {
            //       script {
            //         script("""return ["2","4","8"]""")
            //         sandbox(false)
            //         classpath {}
            //         }
            //         fallbackScript {
            //         script('return[\'获取CPU参数列表失败\']')
            //         sandbox(false)
            //         classpath {}
            //       }
            //     }
            //   }
            // }
            choiceParam("MEM", mem, "每个pod的最大mem，1 = 1Gi")
            // cascadeChoiceParameter {
            //   name("MEM")
            //   description("每个pod的最大mem，1 = 1Gi")
            //   randomName("choice-parameter-563131432116783981")
            //   choiceType("PT_SINGLE_SELECT")
            //   referencedParameters("ENV")
            //   filterLength(1)
            //   script {
            //     groovyScript {
            //       script {
            //         script("""return ["4","8","16"]""")
            //         sandbox(false)
            //         classpath {}
            //         }
            //         fallbackScript {
            //         script('return[\'获取MEM参数列表失败\']')
            //         sandbox(false)
            //         classpath {}
            //       }
            //     }
            //   }
            // }

          }
          definition {
            cpsScm {
              scm {
                git {
                remote {
                  url("git@gitlab-hk.intranet.local:devops/cicd.git")
                  credentials("gitlab-ssh-key")
                }
                branch("*/master")
                }
              }
            scriptPath("jobs/${base_path}/cd-jenkinsfile")
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
                  url("git@gitlab-hk.intranet.local:devops/cicd.git")
                  credentials("gitlab-ssh-key")
                }
                branch("*/master")
                }
              }
            scriptPath("jobs/${base_path}/config-jenkinsfile")
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
                  url("git@gitlab-hk.intranet.local:devops/cicd.git")
                  credentials("gitlab-ssh-key")
                }
                branch("*/master")
                }
              }
            scriptPath("jobs/${base_path}/secret-jenkinsfile")
            }
          }
          disabled(false)
        }
      }

    }
  }
}



