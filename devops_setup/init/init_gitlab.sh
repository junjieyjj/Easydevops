#!/usr/bin/bash
SCRIPT_BASEDIR=$(dirname "$0")

cd ${SCRIPT_BASEDIR}
SCRIPT_BASEDIR="$PWD"
PROJECT_BASEDIR=$(dirname "${SCRIPT_BASEDIR}")

# 加载配置文件
source ${SCRIPT_BASEDIR}/config

echo "step1. Setup gitlab 80/22 port forward to 0.0.0.0 8886/8887"
# 配置gitlab端口转发
kubectl -n ${namespace} port-forward --address 0.0.0.0 svc/gitlab 8886:80 >/dev/null 2>&1 &
kubectl -n ${namespace} port-forward --address 0.0.0.0 svc/gitlab 8887:22 >/dev/null 2>&1 &

echo "step2. Create service user, api token etc."
# 创建service用户
kubectl -n devops exec -it gitlab-0 -- gitlab-rails console <<EOF
service_user = User.create(:name => "${service_user}", :username => "${service_user}", :email => "${service_user}@nomail.com", :password => "${service_password}", :password_confirmation => "${service_password}", :admin => true)
service_user.confirmed_at = Time.zone.now
service_token = service_user.personal_access_tokens.create(scopes: [:api, :read_user, :read_api, :read_repository, :write_repository, :sudo], name: 'gitlab-api-token')
service_token.set_token("${gitlab_api_token}")
service_token.save!
service_user.save!
EOF

echo "step3. Create init group and project"
# 创建poc group
echo "Create poc group and project"
echo "======================================"
poc_group_id=$(curl -s --location --request POST 'http://127.0.0.1:8886/api/v4/groups/' \
--header "Authorization: Bearer ${gitlab_api_token}" \
--header 'Content-Type: application/json' \
--data '{"path": "poc","name": "poc"}' | ${PROJECT_BASEDIR}/tools/jq '.id')

# 创建poc project，替换id值为上面结果的id值
curl --location --request POST "http://127.0.0.1:8886/api/v4/projects?name=spring-boot-demo&namespace_id=${poc_group_id}" \
--header "Authorization: Bearer ${gitlab_api_token}"

# 创建devops group
echo "Create devops group and project"
echo "======================================"
devops_group_id=$(curl --location --request POST 'http://127.0.0.1:8886/api/v4/groups/' \
--header "Authorization: Bearer ${gitlab_api_token}" \
--header 'Content-Type: application/json' \
--data '{"path": "devops","name": "devops"}' | ${PROJECT_BASEDIR}/tools/jq '.id')

# 创建jenkins-shared-library和cicd project，替换id值为上面结果的id值
curl --location --request POST "http://127.0.0.1:8886/api/v4/projects?name=jenkins-shared-library&namespace_id=${devops_group_id}" \
--header "Authorization: Bearer ${gitlab_api_token}"

curl --location --request POST "http://127.0.0.1:8886/api/v4/projects?name=cicd&namespace_id=${devops_group_id}" \
--header "Authorization: Bearer ${gitlab_api_token}"

echo "step4. Add service user ssh public key"
# 上传ssh key到service用户
cp -afr ${PROJECT_BASEDIR}/tools/ssh-key/service.pub ~/.ssh/
cp -afr ${PROJECT_BASEDIR}/tools/ssh-key/service ~/.ssh/

service_user_id=$(curl -s --location --request GET "http://127.0.0.1:8886/api/v4/users?username=service" \
--header "Authorization: Bearer ${gitlab_api_token}" | ${PROJECT_BASEDIR}/tools/jq '.[].id')

curl --location --request POST \
--data-urlencode "key=$ssh_public_key" \
"http://127.0.0.1:8886/api/v4/users/${service_user_id}/keys?title=gitlab-ssh-key" \
--header "Authorization: Bearer ${gitlab_api_token}" 

echo "step5. Git push code to init project"
# 上传仓库
echo 'StrictHostKeyChecking no  
UserKnownHostsFile /dev/null ' \
> ~/.ssh/config

eval "$(ssh-agent -s)"
ssh-add ~/.ssh/service

rm -fr jenkins-shared-library
git clone ssh://git@127.0.0.1:8887/devops/jenkins-shared-library.git 
cd jenkins-shared-library
cp -afr ../code/jenkins-shared-library/* .
git add .
git commit -m "init jenkins-shared-library"
git push -u origin master

cd ${SCRIPT_BASEDIR}
rm -fr cicd
git clone ssh://git@127.0.0.1:8887/devops/cicd.git 
cd cicd
cp -afr ../code/cicd/* .
git add .
git commit -m "init cicd"
git push -u origin master

cd ${SCRIPT_BASEDIR}
rm -fr spring-boot-demo
git clone ssh://git@127.0.0.1:8887/poc/spring-boot-demo.git
cd spring-boot-demo
cp -afr ../code/spring-boot-demo/* .
git add .
git commit -m "init spring-boot-demo"
git push -u origin master

echo "step6. Close port forward and remove local init project"
cd ${SCRIPT_BASEDIR}
rm -fr jenkins-shared-library cicd spring-boot-demo
rm -fr cicd
rm -fr spring-boot-demo

netstat -tnlup | grep 8886 | awk '{print $NF}' | awk -F'/' '{print $1}' | xargs kill -9
netstat -tnlup | grep 8887 | awk '{print $NF}' | awk -F'/' '{print $1}' | xargs kill -9

