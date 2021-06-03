import org.devops.*
import jenkins.model.Jenkins
import hudson.model.Job
import java.io.InputStream
import java.io.FileInputStream
import java.io.File
import javax.xml.transform.stream.StreamSource
import java.util.LinkedHashMap

def call(body) {

    def config = [:]
    body.resolveStrategy = Closure.DELEGATE_FIRST
    body.delegate = config
    body()

    /* 声明全局LinkedHashMap 变量 */
    LinkedHashMap JOBS_MAP

    /* Jenkinsfile CI分支列表 */
    ArrayList CI_BRANCH_LIST = config.CI_BRANCH_LIST ? config.CI_BRANCH_LIST : ["dev", "master"]

    pipeline{
        agent any
        stages{
            stage("Seed_Job") {
                steps{
                    script {
                        /* 获取工作目录、CI分支列表 */
                        String workspace = sh(returnStdout: true, script: """pwd""").trim()
                        ArrayList ci_branch_list = CI_BRANCH_LIST
                        
                        /* 读取dsl groovy写入文件 */
                        def view_definition = libraryResource "dsl/dsl_create_view.groovy"
                        writeFile file: './seed/dsl_create_view.groovy', text: view_definition
                        def eks_job_definition = libraryResource "dsl/dsl_eks_cicd.groovy"
                        writeFile file: './seed/dsl_eks_cicd.groovy', text: eks_job_definition
                        
                        /* 临时保存group，project信息，格式：MapList<Map> [group: [[NAME: project1],[NAME: project2],]] */
                        Map jobs_map = [:]
                        List<String> group_list = get_group_list(workspace)
                        group_list.each{ group ->
                            /* 给每个group初始化一个map, 后面用于保存project信息 */
                            jobs_map."${group}" = []
                        }
                        jobs_map = get_jobs_map(workspace, group_list, jobs_map)

                        /* 遍历所有jobs/group/project下的cd-jenkinsfile，获取参数并转化为map，加入到jobs_map中。格式：[group: [[NAME: project1, DEPLOY_TYPE: eks], [NAME: project2, DEPLOY_TYPE: eks],]] */
                        println jobs_map
                        jobs_map.each{ jm ->
                            /* 遍历group下每个project下的cd-jenkinsfile，获取cd参数 */
                            group = jm.key
                            jobs_map."${group}" = []
                            (jm.value).eachWithIndex{ project_map,index ->
                                project = project_map."NAME"
                                ci_jkfile_path = "AppMetadata/${group}/${project}/CI_Jenkinsfile"
                                cd_jkfile_path = "AppMetadata/${group}/${project}/CD_Jenkinsfile"
                                /* 检查CI和CD jkfile是否存在 */
                                checkCIandCD(group, project)
                                /* 如果ci-jenkinsfile、cd-jenkinsfile存在，则获取全部cicd参数 */
                                if (env.CI_CREATE == "true" && env.CD_CREATE == "true"){
                                    ci_content = readFile(encoding: 'utf-8', file: ci_jkfile_path)
                                    cd_content = readFile(encoding: 'utf-8', file: cd_jkfile_path)
                                    Map job_params = get_ci_params(ci_content) + get_cd_params(cd_content)
                                    checkConfigMapAndSecret(group, project)
                                    job_params."NAME" = project_map."NAME"
                                    job_params."CI_CREATE" = "true"
                                    job_params."CD_CREATE" = "true"
                                    job_params."CONFIGMAP_CONF" = env.CONFIGMAP_CONF
                                    job_params."SECRET_ENV" = env.SECRET_ENV
                                    jobs_map."${group}"[index] = job_params
                                }
                                /* 如果只有ci jenkinsfile，没有cd jenkinsfile，例如公共依赖ci */
                                else if (env.CI_CREATE == "true" && env.CD_CREATE == "false"){
                                    content = readFile(encoding: 'utf-8', file: ci_jkfile_path)
                                    Map job_params = get_ci_params(content)
                                    job_params."NAME" = project_map."NAME"
                                    job_params."CI_CREATE" = "true"
                                    job_params."CD_CREATE" = "false"
                                    jobs_map."${group}"[index] = job_params
                                }
                                /* 如果只有cd jenkinsfile，没有ci jenkinsfile */
                                else if (env.CI_CREATE == "false" && env.CD_CREATE == "true"){
                                    content = readFile(encoding: 'utf-8', file: ci_jkfile_path)
                                    Map job_params = get_cd_params(content)
                                    job_params."NAME" = project_map."NAME"
                                    job_params."CI_CREATE" = "false"
                                    job_params."CD_CREATE" = "true"
                                    jobs_map."${group}"[index] = job_params
                                }
                                else {
                                    return "***ERROR 获取CI_CREATE、CD_CREATE失败"
                                }
                            }
                        }
                        println jobs_map
                        JOBS_MAP = jobs_map

                        jobDsl(
                            ignoreMissingFiles: true, 
                            removedConfigFilesAction: 'DELETE', 
                            removedJobAction: 'DELETE', 
                            removedViewAction: 'DELETE', 
                            targets: 'seed/dsl_eks_cicd.groovy,seed/dsl_create_view.groovy',
                            additionalParameters: [
                                props: [
                                    "gitlab_fqdn": env.GITLAB_FQDN,
                                    "jobs_map": jobs_map,
                                    "ci_branch_list": CI_BRANCH_LIST
                                ]
                            ]
                        )
                    }
                    
                }
            }
            
            // stage("reconfigure jobs") {
            //     steps{
            //         script{
            //             /* reconfigure每一个job */
            //             println(JOBS_MAP)
            //             println(JOBS_MAP.getClass())

            //             /* 遍历jobs，批量更新所有cd、config、secret的job */
            //             JOBS_MAP.each { a ->
            //             group = a.key

            //             (a.value).each{ project_map ->
            //                 project = project_map."NAME"
            //                 group_project = group + "-" + project
            //                 base_path = group + '/' + project
            //                 /* 获取config、secret、cd三个job的fullName */
            //                 configmap_conf_cd_job_fullname = base_path + '/' + 'config_' + group + '_' + project
            //                 secret_env_cd_job_fullname = base_path + '/' + 'secret_' + group + '_' + project
            //                 cd_job_fullname = base_path + '/' + 'cd_' + group + '_' + project
            //                 /* 更新job配置 */
            //                 println("更新${project} job配置：")
            //                 [configmap_conf_cd_job_fullname, secret_env_cd_job_fullname, cd_job_fullname].each{jobFullName -> 
            //                     job = getJobByFullName(jobFullName)
            //                     println(job)
            //                     updateJobConfig(job)
            //                     }
            //                 }
            //             }

            //         }
            //     }
            // }
        
            
        }
    }

}

// 通过Jenkins core api获取job对象
def getJobByFullName(jobFullName){
  Job j
  Jenkins.instance.allItems(Job).each { job -> 
    if(job.fullName == jobFullName){
    	j = job
    }
  }
  return j
}

// 更新job配置
def updateJobConfig(job){
    if(job != null){
        def configXMLFile = job.getConfigFile()
        def file = configXMLFile.getFile()
        InputStream is = new FileInputStream(file)
        job.updateByXml(new StreamSource(is))
        job.save()
    }
}

// 检查项目是否存在CI_Jenkinsfile和CD_Jenkinsfile
def checkCIandCD(group, project) {
    String projectGroupName = "${group}"
    String projectName = "${project}"
    String projectPath = "./AppMetadata/${projectGroupName}/${projectName}"
    String ci_jenkinsfile = "${projectPath}/CI_Jenkinsfile"
    String cd_jenkinsfile = "${projectPath}/CD_Jenkinsfile"

    // 判断ci-jenkinsfile
    if ( fileExists(ci_jenkinsfile) ) {
        env.CI_CREATE = 'true'
    } else {
        env.CI_CREATE = 'false'
    }

    // 判断cd-jenkinsfile
    if ( fileExists(cd_jenkinsfile) ) {
        env.CD_CREATE = 'true'
    } else {
        env.CD_CREATE = 'false'
    }

}

// 检查项目是否存在ConfigMap和Secret
def checkConfigMapAndSecret(group, project) {
    String projectGroupName = "${group}"
    String projectName = "${project}"
    String projectPath = "./AppMetadata/${projectGroupName}/${projectName}"
    String configmap = "${projectPath}/Config_Jenkinsfile"
    String secret = "${projectPath}/Secret_Jenkinsfile"

    // 判断configMap
    if ( fileExists(configmap) ) {
        env.CONFIGMAP_CONF = 'true'
    } else {
        env.CONFIGMAP_CONF = 'false'
    }

    // 判断Secret
    if ( fileExists(secret) ) {
        env.SECRET_ENV = 'true'
    } else {
        env.SECRET_ENV = 'false'
    }

}

@NonCPS
def get_cd_params(content){
    cd_params = [:]
    content.eachMatch('.*=.*'){ re ->
        re.split('\n').each{
            // 过滤带有//注释的变量
            if(it.matches(/\s+\w+\s+=.*/)){
                key = it.split("=")[0].trim()
                if(["ENV", "REPLICA_COUNT", "CPU", "MEM"].contains(key)){
                    /* 一维数组转化为list类型 */
                    value = java.util.Arrays.asList(it.split('=')[1].replaceAll("'","").replaceAll('"',"").replaceAll(" ","").replaceAll("\\[","").replaceAll("\\]","").split(","))
                }
                else{
                    value = it.split("=")[1].trim().replaceAll("'","").replaceAll('"',"")
                }
                // println(key + " " + value)
                cd_params."${key}" = value
            }
        }
    }
    return cd_params
}

@NonCPS
def get_ci_params(content){
    ci_params = [:]
    content.eachMatch('.*=.*'){ re ->
        re.split('\n').each{
            // 过滤带有//注释的变量
            if(it.matches(/\s+\w+\s+=.*/)){
                key = it.split("=")[0].trim()
                value = it.split("=")[1].trim().replaceAll("'","").replaceAll('"',"")
                ci_params."${key}" = value
            }
        }
    }
    return ci_params
}

@NonCPS
def get_group_list(workspace){
    /* 获取group列表，初始化job_map.group = [] */
    ArrayList group_list = []
    new File("${workspace}/AppMetadata").eachFileRecurse() { file -> 
        String path = file.getAbsolutePath()
        // println path
        if (path.split('/').size() != 9) {
            return
        }
        String group = path.split('/')[-3]
        if(!group_list.contains(group)){
            group_list.add(group)
        }
    }
    return group_list
}

@NonCPS
def get_jobs_map(workspace, group_list, jobs_map){
    new File("${workspace}/AppMetadata").eachFileRecurse() { file ->
        String path = file.getAbsolutePath()
        if (path.split('/').size() < 9) {
            return
        }
        String group = path.split('/')[-3]
        String project = path.split('/')[-2]

        /* 把project加入job_map的group中 */
        group_list.each{ g ->
            if(g == group && !(jobs_map."${group}").contains([NAME: project])){
                (jobs_map."${group}").add([NAME: project])
            }
        }
    }
    return jobs_map
}