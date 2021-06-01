# 加载配置文件
source ./config

# 创建service用户
service_user_id=`curl --location --request POST "${gitlab_domain}/api/v4/users" \
--header "Authorization: Bearer ${root_api_token}" \
--header 'Content-Type: application/json' \
--data-raw "{\"admin\": true,\"password\": \"${service_password}\",\"email\": \"${service_user}@nomail.com\",\"username\": \"${service_user}\",\"name\": \"${service_user}\",\"skip_confirmation\": true}" | jq '.id'`
	
# 给用户service创建token（token需要从返回信息里面解析）	
curl --location --request POST "${gitlab_domain}/api/v4/users/103/personal_access_tokens" \
--header "Authorization: Bearer ${root_api_token}" \
--header 'Content-Type: application/json' \
--data-raw "{\"name\": \"api_token\",\"scopes\": \"api,read_user,read_api,read_repository,write_repository\"}"
