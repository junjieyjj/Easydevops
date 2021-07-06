shared-libraries Docs：
https://www.jenkins.io/zh/doc/book/pipeline/shared-libraries/

使用共享库：
// 使用全局配置的默认分支（一般设置为master）
@Library('my-shared-library') _
// 指定分支
@Library('my-shared-library@dev') _

resources目录使用：
// 加载resources目录资源
def request = libraryResource 'dockerfiles/openjdk.Dockerfile'