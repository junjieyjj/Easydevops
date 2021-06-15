#!/usr/bin/bash
SCRIPT_BASEDIR=$(dirname "$0")

cd ${SCRIPT_BASEDIR}
SCRIPT_BASEDIR="$PWD"
PROJECT_BASEDIR=$(dirname "${SCRIPT_BASEDIR}")
LOG_DIR=${PROJECT_BASEDIR}/logs

# include lib
source ${PROJECT_BASEDIR}/lib/utils/logger.sh
source ${PROJECT_BASEDIR}/lib/utils/utils.sh
source ${PROJECT_BASEDIR}/lib/utils/verify.sh
source ${PROJECT_BASEDIR}/lib/k8s/utils.sh

# include config
if [ 0 == $(ps -p $PPID o cmd | grep install.sh | wc -l) ];then
  [ -f "${SCRIPT_BASEDIR}/config" ] && { source ${SCRIPT_BASEDIR}/config; } || { echo_red "ERROR: ${SCRIPT_BASEDIR}/config not exist"; exit 110; }
  [ -f "${PROJECT_BASEDIR}/gitlab-deploy/config" ] && { source ${PROJECT_BASEDIR}/gitlab-deploy/config; } || { echo_red "ERROR: ${PROJECT_BASEDIR}/gitlab-deploy/config not exist"; exit 110; }
else
  [ -f "${PROJECT_BASEDIR}/config" ] && { source ${PROJECT_BASEDIR}/config; } || { echo_red "ERROR: ${PROJECT_BASEDIR}/config not exist"; exit 110; }
fi

# check aws config
check_aws_env

# check config params
verify_params_null \
  ${service_user} \
  ${namespace} \
  ${service_password} \
  ${gitlab_api_token} \
  ${ssh_public_key}

logger_info "step1. Setup gitlab 80/22 port forward to 0.0.0.0 8886/8887"
# 配置gitlab端口转发
kubectl -n ${namespace} port-forward --address 0.0.0.0 svc/gitlab 8886:80 >/dev/null 2>&1 &
kubectl -n ${namespace} port-forward --address 0.0.0.0 svc/gitlab 8887:22 >/dev/null 2>&1 &
check_local_port_listen 8886
check_local_port_listen 8887

logger_info "step2. Create service user, api token etc."
# 创建service用户
kubectl -n ${namespace} exec -it gitlab-0 -- gitlab-rails console <<EOF
service_user = User.create(:name => "${service_user}", :username => "${service_user}", :email => "${service_user}@nomail.com", :password => "${service_password}", :password_confirmation => "${service_password}", :admin => true)
service_user.confirmed_at = Time.zone.now
service_token = service_user.personal_access_tokens.create(scopes: [:api, :read_user, :read_api, :read_repository, :write_repository, :sudo], name: 'gitlab-api-token')
service_token.set_token("${gitlab_api_token}")
service_token.save!
service_user.save!
EOF
[ $? -eq 0 ] && { logger_info "create service user successful"; } || { logger_error "create service user failed"; }

logger_info "step3. Create init group and project"
# 创建poc group
check_http http://127.0.0.1:8886
logger_info "Create poc group and project"
logger_info "======================================"
logger_info "1. create poc group"
poc_group_id=$(curl -s --location --request POST 'http://127.0.0.1:8886/api/v4/groups/' \
--header "Authorization: Bearer ${gitlab_api_token}" \
--header 'Content-Type: application/json' \
--data '{"path": "poc","name": "poc"}' | ${PROJECT_BASEDIR}/tools/jq '.id')
logger_debug "poc_group_id: ${poc_group_id}"

# 创建poc project，替换id值为上面结果的id值
logger_info "2. create poc project"
logger_debug $(curl -s --location --request POST "http://127.0.0.1:8886/api/v4/projects?name=spring-boot-demo&namespace_id=${poc_group_id}" \
--header "Authorization: Bearer ${gitlab_api_token}")


# 创建devops group
logger_info "Create devops group and project"
logger_info "======================================"
logger_info "1. create devops group"
devops_group_id=$(curl --location --request POST 'http://127.0.0.1:8886/api/v4/groups/' \
--header "Authorization: Bearer ${gitlab_api_token}" \
--header 'Content-Type: application/json' \
--data '{"path": "devops","name": "devops"}' | ${PROJECT_BASEDIR}/tools/jq '.id')
logger_debug "devops_group_id: ${devops_group_id}"

# 创建jenkins-shared-library和cicd project，替换id值为上面结果的id值
logger_info "2. create jenkins-shared-library project"
logger_debug $(curl --location --request POST "http://127.0.0.1:8886/api/v4/projects?name=jenkins-shared-library&namespace_id=${devops_group_id}" \
--header "Authorization: Bearer ${gitlab_api_token}")


logger_info "3. create cicd project"
logger_debug $(curl --location --request POST "http://127.0.0.1:8886/api/v4/projects?name=cicd&namespace_id=${devops_group_id}" \
--header "Authorization: Bearer ${gitlab_api_token}")

logger_info "step4. Add service user ssh public key"
# 上传ssh key到service用户
cp -afr ${PROJECT_BASEDIR}/tools/ssh-key/service.pub ~/.ssh/
cp -afr ${PROJECT_BASEDIR}/tools/ssh-key/service ~/.ssh/
chmod 400 ~/.ssh/service.pub ~/.ssh/service

logger_info "1. add public key to service user"
service_user_id=$(curl -s --location --request GET "http://127.0.0.1:8886/api/v4/users?username=service" \
--header "Authorization: Bearer ${gitlab_api_token}" | ${PROJECT_BASEDIR}/tools/jq '.[].id')
logger_debug "service_user_id: ${service_user_id}"

logger_debug $(curl --location --request POST \
--data-urlencode "key=$ssh_public_key" \
"http://127.0.0.1:8886/api/v4/users/${service_user_id}/keys?title=gitlab-ssh-key" \
--header "Authorization: Bearer ${gitlab_api_token}" )

logger_info "step5. Git push code to init project"
# 上传仓库
echo 'StrictHostKeyChecking no  
UserKnownHostsFile /dev/null ' \
> ~/.ssh/config

eval "$(ssh-agent -s)"
ssh-add ~/.ssh/service

check_ssh git 127.0.0.1 8887

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

logger_info "step6. Close port forward and remove local init project"
cd ${SCRIPT_BASEDIR}
rm -fr jenkins-shared-library cicd spring-boot-demo
rm -fr cicd
rm -fr spring-boot-demo

netstat -tnlup | grep 8886 | awk '{print $NF}' | awk -F'/' '{print $1}' | xargs kill -9
netstat -tnlup | grep 8887 | awk '{print $NF}' | awk -F'/' '{print $1}' | xargs kill -9

