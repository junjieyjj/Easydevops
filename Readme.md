#  Easydevops
![](https://img.shields.io/badge/platform-Linux-blue)&nbsp;&nbsp;![](https://img.shields.io/badge/language-shell-blue)&nbsp;&nbsp;![](https://img.shields.io/badge/language-groovy-blue)&nbsp;&nbsp;[![](https://img.shields.io/badge/license-Apache%202-red)](https://github.com/junjieyjj/Easydevops/blob/master/LICENSE)

# 项目介绍

一键在AWS EKS上容器化部署和初始化配置DevOps工具链（gitlab、sonarqube、jenkins）


# 准备工作

## 1、准备一台Centos7 EC2

EKS集群安全组必须放通ecs所在网段，必须可以与devops k8s集群通信



## 2、yum安装常用工具

```bash
yum install -y git bind-utils unzip net-tools jq bash-completion
```



## 3、安装aws cli

```bash
cd tools
unzip awscliv2.zip
cd aws
./install

aws --version
输出以下信息说明安装成功：
aws-cli/2.2.5 Python/3.8.8 Linux/3.10.0-1160.15.2.el7.x86_64 exe/x86_64.centos.7 prompt/off
```



## 4、安装helm3

```bash
cd tools
tar zxf helm-v3.5.4-linux-amd64.tar.gz
mv linux-amd64/helm /usr/local/bin
chmod +x /usr/local/bin/helm

helm version
输出以下信息说明安装成功：
version.BuildInfo{Version:"v3.5.4", GitCommit:"1b5edb69df3d3a08df77c9902dc17af864ff05d1", GitTreeState:"clean", GoVersion:"go1.15.11"}
```



## 5、安装kubectl

```bash
# 安装Kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x kubectl
mv kubectl /usr/local/bin/

# kubectl自动补全
echo 'source <(kubectl completion bash)' >>~/.bashrc
重新登录会话
```



## 6、安装efs-csi-driver

> 参考文档：
>
> https://docs.aws.amazon.com/zh_cn/eks/latest/userguide/efs-csi.html

```bash
kubectl kustomize \
    "github.com/kubernetes-sigs/aws-efs-csi-driver/deploy/kubernetes/overlays/stable/ecr?ref=release-1.2" > driver.yaml

kubectl apply -f driver.yaml
```



## 7、创建efs文件系统

EKS启动的pod必须能够挂载efs文件系统



# 镜像准备

需用户自行把组件镜像推送到k8s可访问私有仓库，如集群可访问公网，也可直接使用官方公仓镜像

| 镜像名称           | 官方公仓镜像                                                 |
| ------------------ | ------------------------------------------------------------ |
| Curl               | curl:latest                                                  |
| Busybox            | centos:7，内置psql命令                                       |
| Gitlab             | gitlab-ce:12.10.14-ce.0                                      |
| Sonarqube          | sonarqube:8.5.1-community                                    |
| Sonarqube(plugins) | sonarqube-plugins:8.5.1                                      |
| Jenkins            | jenkins:2.293-plugins                                        |
| Jenkins-slave      | jenkins-slave:centos |
|                    |                                                              |



# 中间件准备

| 类型       | 版本  | 用途                                               |
| ---------- | ----- | -------------------------------------------------- |
| PostgreSql | 11.9  | Gitlab数据库，用户必须具有superuser权限            |
| Redis      | 6.0.5 | Gitlab缓存数据库，不需要设置密码，只能是主从版本，不能使用集群版本 |
| PostgreSql | 11.7  | Sonarqube数据库，用户必须具有superuser权限         |
|            |       |                                                    |



# 执行步骤

## 注意

1、脚本运行需要临时占用本地8886、8887、8888端口，请确保运行脚本前不要占用这三个端口



## 1、获取kubeconfig

获取需要部署DevOps组件到的eks集群配置文件，用户必须具有集群管理员权限，确保kubectl可以创建集群资源

```bash
export AWS_ACCESS_KEY_ID=xxxxxx
export AWS_SECRET_ACCESS_KEY=xxxxxxxx
export AWS_DEFAULT_REGION=xxxxxx
export EKS_CLUSTER=xxxxx

aws eks --region ${AWS_DEFAULT_REGION} update-kubeconfig --name ${EKS_CLUSTER}
```



## 2、执行脚本部署gitlab、sonarqube、jenkins

```bash
配置config参数

执行命令：sh ./install.sh

------------------------------------------------------------------
1. One-keyed DevOps deploy (gitlab, sonarqube, jenkins)
2. Deploy ingress
3. Gitlab upgrade
4. Sonarqube upgrade
5. Jenkins upgrade
6. Delete all resources
------------------------------------------------------------------

please give me your choice: 1
```



## 3、执行脚本部署ingress

```bash
配置config参数

执行命令：sh ./install.sh

------------------------------------------------------------------
1. One-keyed DevOps deploy (gitlab, sonarqube, jenkins)
2. Deploy ingress
3. Gitlab upgrade
4. Sonarqube upgrade
5. Jenkins upgrade
6. Delete all resources
------------------------------------------------------------------

please give me your choice: 2
```

Load Balance资源创建需要一些时间，大概等待5分钟



## 4、测试

Command

```bash
source ./config
kubectl -n ${namespace} get ingress devops 

Output:
NAME     CLASS    HOSTS                                                 ADDRESS                                                                         PORTS   AGE
devops   <none>   gitlab.demo.com,jenkins.demo.com,sonarqube.demo.com   a182ebec36cb5497aa1480acfda8d92c-58c77428846355af.elb.ap-east-1.amazonaws.com   80      23h
```



Test Command:

```bash
curl -s -I -H "HOST: ${gitlab_fqdn}" \
http://a182ebec36cb5497aa1480acfda8d92c-58c77428846355af.elb.ap-east-1.amazonaws.com

Output:
HTTP/1.1 302 Found
Date: Wed, 23 Jun 2021 07:40:10 GMT
Content-Type: text/html; charset=utf-8
Connection: keep-alive
Cache-Control: no-cache
Location: http://gitlab.demo.com/users/sign_in
...


curl -s -I -H "HOST: ${sonarqube_fqdn}" \
http://a182ebec36cb5497aa1480acfda8d92c-58c77428846355af.elb.ap-east-1.amazonaws.com

Output:
HTTP/1.1 200 
Date: Wed, 23 Jun 2021 07:41:12 GMT
Content-Type: text/html;charset=utf-8
Connection: keep-alive
...


curl -s -I -H "HOST: ${jenkins_fqdn}" \
http://a182ebec36cb5497aa1480acfda8d92c-58c77428846355af.elb.ap-east-1.amazonaws.com

Output:
HTTP/1.1 200 OK
Date: Wed, 23 Jun 2021 07:42:10 GMT
Content-Type: text/html;charset=utf-8
Content-Length: 20528
Connection: keep-alive
X-Content-Type-Options: nosniff
Expires: Thu, 01 Jan 1970 00:00:00 GMT
...
```



## 5、配置DevOps组件fqdn指向LoadBalance fqdn

通过cname方式把DevOps组件域名指向loadbalance域名，才能从外部通过fqdn访问组件

```
gitlab.demo.com ----> a182ebec36cb5497aa1480acfda8d92c-58c77428846355af.elb.ap-east-1.amazonaws.com

sonarqube.demo.com ----> a182ebec36cb5497aa1480acfda8d92c-58c77428846355af.elb.ap-east-1.amazonaws.com

jenkins.demo.com ----> a182ebec36cb5497aa1480acfda8d92c-58c77428846355af.elb.ap-east-1.amazonaws.com
```
