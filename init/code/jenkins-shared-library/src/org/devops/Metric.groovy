#!groovy
package org.devops

/*
 * 块调用示例：
 * jenkins.metric {
 *      log.info ("Start recording metrics")
 *      log.info ("延迟1秒")
 *      sleep(1)
 * }
 */

// 定义闭包对象(块调用)
def call(Closure body) {
    def log = new Log()

    def start_time = new Date()
    body()
    def end_time = new Date()
    def exec_time = end_time.getTime() - start_time.getTime()
    log.info ("StageName:${env.STAGE_NAME}, ExecutionTime:${exec_time}ms")

    return [exec_time, env.STAGE_NAME]
}

// 定义闭包对象(块调用)
def pushMysql(Closure body) {
    def log = new Log()

    def start_time = new Date()
    body()
    def end_time = new Date()
    def exec_time = end_time.getTime() - start_time.getTime()
    log.info ("StageName:${env.STAGE_NAME}, ExecutionTime:${exec_time}ms")
    log.info ("Insert metrics into MySQL")

    return [exec_time, env.STAGE_NAME]
}