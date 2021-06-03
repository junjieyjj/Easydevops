# 程序账号
## Gitlab
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

## Sonarqube
用户名 / 密码
service / IkwSNV$32%29sjw

用户名 / api token
service / dd782318e860ffb12ba591706e3c311f532cac54

## Jenkins
service / IkwSNV$32%29sjw

## EKS
kubeconfig配置文件


# 执行步骤

1. 使用脚本部署gitlab
```bash
配置gitlab-deploy/config参数

执行命令：sh ./run.sh
```

2. gitlab部署成功后，进行初始化（创建service账号、token、上传ssh公钥、创建group、project）

- **检验gitlab是否部署成功**
```
cd gitlab-deploy
source config
kubectl -n ${namespace} get pod gitlab-0
PS：状态为1/1 Running为成功，如：
gitlab-0                               1/1     Running   0          11m

```

- **进入gitlab容器创建service账号、api token、group和project**
```bash
kubectl -n ${namespace} exec -it gitlab-0 bash

# 创建service账号和api token
gitlab-rails console

service_user = User.create(:name => "service", :username => "service", :email => "service@nomail.com", :password => "IkwSNV$32%29sjw", :password_confirmation => "IkwSNV$32%29sjw", :admin => true)

service_user.confirmed_at = Time.zone.now

service_token = service_user.personal_access_tokens.create(scopes: [:api, :read_user, :read_api, :read_repository, :write_repository, :sudo], name: 'gitlab-api-token')

service_token.set_token('p33McqT6NZrVxzeEmeCy')

service_token.save!
service_user.save!

执行上面命令后退出终端<ctrl> + d

# 创建poc group
curl --location --request POST 'http://127.0.0.1:80/api/v4/groups/' \
--header 'Authorization: Bearer p33McqT6NZrVxzeEmeCy' \
--header 'Content-Type: application/json' \
--data-raw '{"path": "poc","name": "poc"}'

记录执行结果{"id":169,...}

# 创建poc project
curl --location --request POST 'http://127.0.0.1:80/api/v4/projects?name=spring-boot-demo&namespace_id=169' \
--header 'Authorization: Bearer p33McqT6NZrVxzeEmeCy'

# 创建devops group
curl --location --request POST 'http://127.0.0.1:80/api/v4/groups/' \
--header 'Authorization: Bearer p33McqT6NZrVxzeEmeCy' \
--header 'Content-Type: application/json' \
--data-raw '{"path": "devops","name": "devops"}'

记录执行结果{"id":170,...}

# 创建jenkins-shared-library和cicd project
curl --location --request POST 'http://127.0.0.1:80/api/v4/projects?name=jenkins-shared-library&namespace_id=170' \
--header 'Authorization: Bearer p33McqT6NZrVxzeEmeCy'

curl --location --request POST 'http://127.0.0.1:80/api/v4/projects?name=cicd&namespace_id=170' \
--header 'Authorization: Bearer p33McqT6NZrVxzeEmeCy'
```

- **登录service账号，上传ssh公钥**
```
公钥路径：tools/ssh-key/service.pub
```

- **上传jenkins-shared-library、poc、cicd代码**
```
# 设置gitlab端口转发到本地
kubectl -n ${namespace} port-forward --address 0.0.0.0 svc/gitlab 8886:80 >/dev/null 2>&1 &

git clone http://127.0.0.1:8886/devops/jenkins-shared-library.git
cd jenkins-shared-library
cp -afr code/jenkins-shared-library/* .
git add .
git commit -m "init jenkins-shared-library"
git push -u origin master

cd ..
git clone http://127.0.0.1:8886/devops/cicd.git
cd cicd
cp -afr code/cicd/* .
git add .
git commit -m "init cicd"
git push -u origin master

cd ..
git clone http://127.0.0.1:8886/poc/spring-boot-demo.git
cd spring-boot-demo
cp -afr code/spring-boot-demo/* .
git add .
git commit -m "init spring-boot-demo"
git push -u origin master
```

3. 使用脚本部署sonarqube
```bash
配置sonarqube-deploy/config参数

执行命令：sh ./run.sh
```

4. sonarqube初始化（创建service账号，token、回调jenkins webhook）

- **检验sonarqube是否部署成功**
```
cd sonarqube-deploy
source config
kubectl -n ${namespace} get pod | grep sonarqube
PS：状态为1/1 Running为成功，如：
sonarqube-sonarqube-7b65b8bc75-h2vck   1/1     Running   0          146m
```

- **进入sonarqube容器创建service账号、api token**
```bash
# 设置sonarqube端口转发到本地
kubectl -n ${namespace} port-forward --address 0.0.0.0 svc/sonarqube-sonarqube 8885:9000 >/dev/null 2>&1 &

# 创建service用户
curl -X POST -u admin:${sonarqube_admin_password} -d "login=service&name=service&email=service@nomail.com&password=IkwSNV$32%29sjw" "http://127.0.0.1:8885/api/users/create"

# 创建service用户api token
curl -X POST -u admin:${sonarqube_admin_password} -d "login=service&name=sonarqube-api-token" "http://127.0.0.1:8885/api/user_tokens/generate"

记录执行结果{..,"token":"8705144caa226e70cf385abd09bd4a082c2687e9",..}

# 创建sonarqube回调jenkins webhook
curl -u admin:${sonarqube_admin_password} -X POST -d "name=jenkins&url=http://jenkins.demo.com/sonarqube-webhook/" "http://127.0.0.1:8885/api/webhooks/create"

# 停止sonarqube端口转发
netstat -tnlup | grep 8885 | awk '{print $NF}' | awk -F'/' '{print $1}' | xargs kill -9
```




5. 上传jenkins插件到s3
```bash
命令：
aws s3api put-object --bucket <bucket-name> --key jenkins-3.3.9-plugins.tar.gz --body jenkins-3.3.9-plugins.tar.gz

示例：
aws s3api put-object --bucket jack-test-devops --key jenkins-3.3.9-plugins.tar.gz --body jenkins-3.3.9-plugins.tar.gz
```

6. 赋予jenkins-plugins.tgz插件的s3的下载权限

7. 使用脚本部署jenkins
```bash
配置jenkins-deploy/config参数

执行命令：sh ./run.sh
```



# 问题
## Jenkins
1. token以明文方式存在配置文件中

2. shell无法通过环境变量渲染GITLAB_SSH_PRIVATE_KEY，明文写死在jcasc.yaml.template

3. 
