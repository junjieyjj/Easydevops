# 准备工作

## 1、准备一台Centos7 EC2

必须可以与devops k8s集群通信



## 2、安装aws cli

```bash
cd tools
yum install -y unzip
unzip awscliv2.zip
cd aws
./install

aws --version
输出以下信息说明安装成功：
aws-cli/2.2.5 Python/3.8.8 Linux/3.10.0-1160.15.2.el7.x86_64 exe/x86_64.centos.7 prompt/off
```



## 3、安装helm3

```bash
cd tools
tar zxf helm-v3.5.4-linux-amd64.tar.gz
mv linux-amd64/helm /usr/local/bin
chmod +x /usr/local/bin/helm

helm version
输出以下信息说明安装成功：
version.BuildInfo{Version:"v3.5.4", GitCommit:"1b5edb69df3d3a08df77c9902dc17af864ff05d1", GitTreeState:"clean", GoVersion:"go1.15.11"}
```



## 4、安装kubectl

```bash
# 安装Kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x kubectl
mv kubectl /usr/local/bin/

# kubectl自动补全
yum -y install bash-completion
echo 'source <(kubectl completion bash)' >>~/.bashrc
重新登录会话
```



## 5、安装git

```
yum install -y git
```



## 6、镜像准备

需用户自行把组件镜像推送到k8s可访问私有仓库，如集群可访问公网，也可直接使用官方公仓镜像

| 镜像名称   | 官方公仓镜像              |
| ---------- | ------------------------- |
| 初始化容器 | curl:latest               |
| 初始化容器 | busybox:1.32              |
| Gitlab     | gitlab-ce:12.10.14-ce.0   |
| Sonarqube  | sonarqube:8.5.1-community |
| Jenkins    | jenkins:2.277.3-lts       |
|            |                           |



## 7、中间件准备

| 类型       | 版本  | 用途                                               |
| ---------- | ----- | -------------------------------------------------- |
| PostgreSql | 11.9  | Gitlab数据库                                       |
| Redis      | 6.0.5 | Gitlab缓存数据库，只能是主从版本，不能使用集群版本 |
| PostgreSql | 11.7  | Sonarqube数据库                                    |
| S3         | AWS   | 保存初始化的Jenkins插件                            |



## 8、上传jenkins插件到s3，、赋予jenkins-plugins.tgz插件的s3的下载权限

```bash
命令：
aws s3api put-object --bucket <bucket-name> --key jenkins-3.3.9-plugins.tar.gz --body jenkins-3.3.9-plugins.tar.gz

示例：
aws s3api put-object --bucket jack-test-devops --key jenkins-3.3.9-plugins.tar.gz --body jenkins-3.3.9-plugins.tar.gz
```



# 执行步骤

## 1、使用脚本创建efs持久化目录

```bash
配置infra/config参数

执行命令：sh ./run.sh
```



## 2、使用脚本部署gitlab
```bash
配置gitlab-deploy/config参数

执行命令：sh ./run.sh
```



## 3、使用脚本初始化gitlab

```bash
配置init/config参数

执行命令：sh ./init_gitlab.sh
```



## 4、使用脚本部署sonarqube

```bash
配置sonarqube-deploy/config参数

执行命令：sh ./run.sh
```



## 5、使用脚本初始化sonarqube

```bash
配置init/config参数

执行命令：sh ./init_sonarqube.sh
```



## 6、使用脚本部署jenkins

```bash
配置jenkins-deploy/config参数

执行命令：sh ./run.sh

# 设置jenkins端口转发到本地
source ./config
kubectl -n ${namespace} port-forward --address 0.0.0.0 svc/jenkins 8888:8080 >/dev/null 2>&1 &
```



## 7、使用脚本配置ingress

```bash
配置nlb/config参数
执行命令：sh ./run.sh
```





## 9、创建dsl job、poc job测试

```bash
# 创建seed-job
New Item -> 流水线
name: seed-job
Pipeline -> Pipeline script from SCM -> Git 
Repository URL：git@gitlab.demo.com:devops/cicd.git
Credentials：service(gitlab-ssh-key)
Script Path：SeedJob_Jenkinsfile

执行seed-job，通过dsl生成cicd

```



## 10、测试完成后，停止端口转发

```
netstat -tnlup | grep 8885 | awk '{print $NF}' | awk -F'/' '{print $1}' | xargs kill -9
netstat -tnlup | grep 8886 | awk '{print $NF}' | awk -F'/' '{print $1}' | xargs kill -9
netstat -tnlup | grep 8888 | awk '{print $NF}' | awk -F'/' '{print $1}' | xargs kill -9
```





# 账号信息

## Gitlab
```bash
用户名 / 密码
service / IkwSNV$32%29sjw

用户名 / api token
service / p33McqT6NZrVxzeEmeCy

ssh key

service.pub
-----------------
ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDMFez1WfsLWYyFoW6cIe/ODn8oblloLwXjwaAvAsQ5exKD5Rat+Wo4njjWMHO48rNnMJcnpu2Au/Nd2kMFkbB2hJ/frlIAHbJuYsOCyKydKwJzSmtr8AHVAnr+TIvgpn+MCtOAXII0MssRY25UILwB5YvG+iJvYTkZACp51rRhsF3qAJAxPBFoNxUh8+HPhyXdWHFyN/ElmBQNH3V7V7FUc/FaiiRd8/ozh7YsoBjtC9/Rt9ahBBd7wtrzOQujpijA3BlJFoGs1R1ramLlyLT5NLz0yN1p6+4i3CCMUHs9oYvOYa6iXhbUF3KIY/YnejLgH3hDiyg0TvVJ0Hb5gqcx service

service
-----------------
-----BEGIN RSA PRIVATE KEY-----
MIIEpQIBAAKCAQEAzBXs9Vn7C1mMhaFunCHvzg5/KG5ZaC8F48GgLwLEOXsSg+UW
rflqOJ441jBzuPKzZzCXJ6btgLvzXdpDBZGwdoSf365SAB2ybmLDgsisnSsCc0pr
a/AB1QJ6/kyL4KZ/jArTgFyCNDLLEWNuVCC8AeWLxvoib2E5GQAqeda0YbBd6gCQ
MTwRaDcVIfPhz4cl3VhxcjfxJZgUDR91e1exVHPxWookXfP6M4e2LKAY7Qvf0bfW
oQQXe8La8zkLo6YowNwZSRaBrNUda2pi5ci0+TS89MjdaevuItwgjFB7PaGLzmGu
ol4W1BdyiGP2J3oy4B94Q4soNE71SdB2+YKnMQIDAQABAoIBAQCjnlhxhAhO2yZb
5EbHijW13812XrHzYu+3335K8k7bPp5jfAEozbOpXMB4iDPe7UWDz2L/+UakVQsS
DXB6QIlXG5EJRbqcOTLaaPgSHEy3XMoEIH/q82qkme59fmUOYK4VWoCigogozSgc
8rh7Xhsc8imUBuognbOnJYjoUYggYFTbLw46e/I0Db8S+phbZ936ToRIHzsBpyL4
RuAWKbGdyEGvS7FJ1B3P0+GdwvATE4GiutSRLPVW037rr34slK5Dg8H0Ll7DzPa6
4m6hRV29IuKbuJcGC3XFg8gkFl88RQE4rb+TNnfv+RDMQid1yahbZoflWqKQkkjJ
nrEfynGBAoGBAOvRuuz2iEdnuNEiE+EP6y/WNrk0Xsn/p0dOYkewX9TkAXqoOfom
7U7Oe/M56pSaqowTaNXtE9z/nbkhwA/levSKokx4x+184qRcOUTlg1/xWSwChAQT
1VTdPboS2LIdwvwjEKrzdTwlDLAiza9yHdilCUVF2tUZ/Ri54R46JSmJAoGBAN2M
+7zPoz/I5A/SztOSlBIo3XS83I7bA4kcWyCI/5lwIstmDhgBMKug/IOSL60BYCAE
mpDQxmH4ls3N7uw6ptRS+2D6/JVTmpp26tT1BA7ZBax9yTw7IeTCLRyGAba7u5wf
0+cFDS+qBMg8tC8HhYrIbXciqrjNGXuGsJt+3i5pAoGBANnPWYvNGYp6buYbR6k0
/tGsVdcyW+rPSz49U+FLMvh7sDIOd55pnf6QEURSVizzvlqrAsW0uAgDwTZhyffk
yXBdLBLd7Cuakeulku/j3Tgcv3Q6zpzFhOFhh8X56lR50ML50EdVnw7yWYnGW5yV
FqQnqyxknP7/hhn0dc1pfzGhAoGBALXsid5uBhhfZt6TdWCIUWxkAA1W9CmeMFYL
Yczikjg1u2yX/eS6PXQBerizdtCye3NvNFjMBsr2LScL/jAerVVWWrM1Bem8wAws
sAJ0u4NRs/YDSBZcXCWTSSXN6GRb3d+CxydBn6VPECQ4rKCdpYvjrveQEO41BMLJ
RAY7dEhZAoGAI3Zxe0QXs2fShm+KevFQ86oAKUMRvrga4DUdp20Yazs+IRye7GnF
b+hlphmIXJuFXnNyjhvht0ucBZh/lOFPjdjNji69zvjGF8e9VxaHFqKcBEp6Q7J/
1Yq/aZz/eZ1X2Q5A+fkBkhskIRpstroPwZljtqV0rDlc02MDYipJQ7E=
-----END RSA PRIVATE KEY-----
```



## Sonarqube
```bash
用户名 / 密码
service / IkwSNV$32%29sjw

用户名 / api token
service / dd782318e860ffb12ba591706e3c311f532cac54
```



## Jenkins
```bash
service / IkwSNV$32%29sjw
```



