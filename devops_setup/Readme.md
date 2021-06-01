# 程序账号
## Gitlab
用户名 / 密码
service / IkwSNV$32%29sjw

用户名 / api token
service / 

## Sonarqube
用户名 / 密码
service / IkwSNV$32%29sjw

用户名 / api token
service / 

## Jenkins
service / IkwSNV$32%29sjw

## EKS
kubeconfig配置文件


# 前置步骤
1. 上传jenkins插件到s3
```bash
命令：
aws s3api put-object --bucket <bucket-name> --key jenkins-3.3.9-plugins.tar.gz --body jenkins-3.3.9-plugins.tar.gz

示例：
aws s3api put-object --bucket jack-test-devops --key jenkins-3.3.9-plugins.tar.gz --body jenkins-3.3.9-plugins.tar.gz
```