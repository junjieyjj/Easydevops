#!groovy
package org.devops
import java.text.SimpleDateFormat

// 获取当前构建任务用户ID
@NonCPS
def getBuildUserId() {
    try {
        def userId = currentBuild.rawBuild.getCause(Cause.UserIdCause).getUserId()
        return userId
    }
    catch (Exception e) {
        return null
    }
}

// 获取当前构建任务用户名
@NonCPS
def getBuildUserName() {
    try {
        def userName = currentBuild.rawBuild.getCause(Cause.UserIdCause).getUserName()
        return userName
    }
    catch (Exception e) {
        return null
    }
}

// 获取任务构建类型（判断由用户手动执行或是触发执行，用户名为空时为Webhook触发）
def getJobTriggerBuildType() {
    if ( getBuildUserId() != null ) {
        result = 'ManualBuild'
    } else {
        result = 'TriggerBuild'
    }

    return result
}

// 获取项目信息（从Job路径、Job名称获取Group、Project）
def getProjectInfo() {
    env.PROJECT_GROUP_NAME = env.JOB_NAME.tokenize('/')[0].toLowerCase()
    env.PROJECT_NAME = env.JOB_BASE_NAME.tokenize('_')[-1].toLowerCase()

    println """\
    ***INFO：Add ProjectInfo to the global environment variable
    ***INFO：PROJECT_GROUP_NAME：${env.PROJECT_GROUP_NAME}
    ***INFO：PROJECT_NAME：${env.PROJECT_NAME}
    """.stripIndent()
}

// 设置当次构建显示名称
def setJobDisplayName(String jobType) {
    String buildNum = "v" + env.BUILD_NUMBER.trim()
    String branch = env.GIT_BRANCH_NAME ?: 'null'
    String gitCommit = env.GIT_COMMIT_SHORT ?: 'null'

    long unixTimestamp = currentBuild.startTimeInMillis
    String startTime = new SimpleDateFormat("yyyyMMddHHmmss").format(unixTimestamp)

    switch( jobType?.toUpperCase() )
    {
        case ~/(?i)CD|SECRET/:
            currentBuild.displayName = buildNum + "-" + startTime
            break

        default:
            currentBuild.displayName = buildNum + "-" + startTime + "-" + branch + "-" + gitCommit
    }

    return currentBuild.displayName
}

// 设置当次构建任务描述（执行人、构建类型、分支、环境）
def setJobDesc(String jobType) {
    String buildUserId = getBuildUserId()
    String buildUserName = getBuildUserName()
    String jobBuildType = getJobTriggerBuildType()
    String deploy_env = env.ENV
    // String namespace = env.NAMESPACE
    String buildTagName = env.BUILD_TAG_NAME ?: 'null'

    if ( jobType.toUpperCase() == 'CI' ) {
        currentBuild.description =
            "用户ID：" + buildUserId + "\n" +
            "用户名称：" + buildUserName + "\n" +
            "构建类型：" + jobBuildType
    }

    if ( jobType.toUpperCase() == 'CD' ) {
        // 【参数化构建】-【运行时参数】-【名称】填写变量名：BUILD_TAG，后续使用BUILD_TAG_NAME获取构建名称
        // 【参数化构建】-【运行时参数】-【项目】填写要获取的Job的名称（包括文件夹路径），如：smu/web-portal
        //  run(name: 'BUILD_TAG', projectName: "${env.PROJECT_GROUP_NAME}/ci_${env.PROJECT_NAME}", filter: 'SUCCESSFUL')
        currentBuild.description =
            "用户ID：" + buildUserId + "\n" +
            "用户名称：" + buildUserName + "\n" +
            "构建类型：" + jobBuildType + "\n" +
            "关联标签：" + buildTagName + "\n" +
            "发布环境：" + deploy_env
    }

    if ( jobType.toUpperCase() =~ /CONFIG|SECRET/ ) {
        currentBuild.description =
            "用户ID：" + buildUserId + "\n" +
            "用户名称：" + buildUserName + "\n" +
            "构建类型：" + jobBuildType + "\n" +
            "发布环境：" + deploy_env
    }

    return currentBuild.description
}

// 获取开始运行时间，将其添加为全局环境变量，后面作为Tag的一部
//env.START_TIME = new Date().format("yyyyMMddHHmmss",TimeZone.getTimeZone('Asia/Shanghai'))
