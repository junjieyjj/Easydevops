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


# 前置步骤
1. 上传jenkins插件到s3
```bash
命令：
aws s3api put-object --bucket <bucket-name> --key jenkins-3.3.9-plugins.tar.gz --body jenkins-3.3.9-plugins.tar.gz

示例：
aws s3api put-object --bucket jack-test-devops --key jenkins-3.3.9-plugins.tar.gz --body jenkins-3.3.9-plugins.tar.gz
```

2. 赋予插件文件的s3的下载权限

3. gitlab初始化（创建service账号、token、上传ssh公钥）

4. sonarqube初始化（创建service账号，token、回调jenkins webhook）

# 问题
## Jenkins
1. token以明文方式存在配置文件中

2. shell无法通过环境变量渲染GITLAB_SSH_PRIVATE_KEY，明文写死在jcasc.yaml.template

3. 
