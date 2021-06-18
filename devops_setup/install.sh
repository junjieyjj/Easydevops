#!/usr/bin/bash
SCRIPT_BASEDIR=$(dirname "$0")

cd ${SCRIPT_BASEDIR}
SCRIPT_BASEDIR="$PWD"
LOG_DIR=${SCRIPT_BASEDIR}/logs

# include lib
source ${SCRIPT_BASEDIR}/lib/utils/logger.sh
source ${SCRIPT_BASEDIR}/lib/utils/utils.sh
source ${SCRIPT_BASEDIR}/lib/utils/verify.sh
source ${SCRIPT_BASEDIR}/lib/k8s/utils.sh
source ${SCRIPT_BASEDIR}/config

# check aws config
check_aws_env

all_deploy() {
    # Create EFS persistent volume and persistent volume claim
    logger_info "Stage0. create EFS persistent volume and persistent volume claim"
    create_init_pod
    sh infra/create_shared_volume_dir.sh
    revalue=$?
    if [[ "${revalue}" == 110 ]]
    then
        exit 1
    fi
    logger_info "Stage0 done.."
    echo

    # Deploy Gitlab 
    logger_info "Stage1. deploy gitlab componment"
    sh gitlab-deploy/run.sh
    revalue=$?
    if [[ "${revalue}" == 110 ]]
    then
        exit 1
    fi

    sh init/init_gitlab.sh
    revalue=$?
    if [[ "${revalue}" == 110 ]]
    then
        exit 1
    fi
    logger_info "Stage1 done.."
    echo

    # Deploy Sonarqube
    logger_info "Stage2. deploy sonarqube componment"
    sh sonarqube-deploy/run.sh
    revalue=$?
    if [[ "${revalue}" == 110 ]]
    then
        exit 1
    fi

    sh init/init_sonarqube.sh
    revalue=$?
    if [[ "${revalue}" == 110 ]]
    then
        exit 1
    fi
    logger_info "Stage2 done.."
    export sonarqube_api_token=$(cat init/sonarqube-api-token)

    # Deploy Jenkins
    logger_info "Stage3. deploy jenkins componment"
    sh jenkins-deploy/run.sh
    revalue=$?
    if [[ "${revalue}" == 110 ]]
    then
        exit 1
    fi
    logger_info "Stage3 done.."
    echo

    logger_info "Stage4 delete busybox pod"
    sh infra/delete_init_pod.sh
}

create_init_pod(){
    sh infra/create_init_pod.sh
    revalue=$?
    if [[ "${revalue}" == 110 ]]
    then
        exit 1
    fi
}

deploy_ingress(){
    # Deploy ingress
    logger_info "Deploy ingress componment"
    sh nlb/run.sh
    revalue=$?
    if [[ "${revalue}" == 110 ]]
    then
        exit 1
    fi
    logger_info "Deploy ingress done.."
}

list_resources(){
    echo -e "\033[1;36m1. Helm Release\033[0m"
    echo "NAME    NAMESPACE       REVISION        UPDATED                                 STATUS          CHART             APP VERSION"
    helm -n ${namespace} list | grep -E 'gitlab|sonarqube|jenkins'
    echo
    echo -e "\033[1;36m2. Shared Volume /jenkins /sonarqube /gitlab /jenkins-slave\033[0m"
    echo 
    echo -e "\033[1;36m3. All tables in gitlab postgresql database ${gitlab_postgresql_db_database}\033[0m"
    echo 
    echo -e "\033[1;36m4. All tables in sonarqube postgresql database ${sonarqube_postgresql_db_database}\033[0m"
    echo 
    echo -e "\033[1;36m5. PV, PVC resources\033[0m"
    echo 'NAME               CAPACITY   ACCESS MODES   RECLAIM POLICY   STATUS   CLAIM                             STORAGECLASS   REASON   AGE'
    kubectl get pv | grep -E 'gitlab-pv|jenkins-pv|sonarqube-pv|jenkins-slave-pv'
    echo
    echo 'NAME            STATUS   VOLUME         CAPACITY   ACCESS MODES   STORAGECLASS   AGE'
    kubectl -n ${namespace} get pvc | grep -E 'gitlab-pvc|jenkins-pvc|sonarqube-pvc'
    kubectl -n ${jenkins_slave_namespace} get pvc | grep -E 'jenkins-slave-pv'
    echo
    
}

delete_resources(){
    create_init_pod
    echo -e "\033[1;36m1. Delete helm Release:\033[0m"
    resources_count=$(helm -n ${namespace} list | grep -E 'gitlab|sonarqube|jenkins' | wc -l)
    if [ ${resources_count} -gt 0 ];then
        helm -n ${namespace} list | grep -E 'gitlab|sonarqube|jenkins' | awk '{print $1}' | while read line
        do
            helm -n ${namespace} uninstall $line
        done
    else
        echo 'no releases'
    fi
    echo
    echo -e "\033[1;36m2. delete shared Volume /jenkins /sonarqube /gitlab /jenkins-slave\033[0m"
    kubectl -n ${namespace} exec -it busybox sh -- rm -fr /data/jenkins /data/sonarqube /data/gitlab /data/jenkins-slave
    echo
    echo -e "\033[1;36m3. delete all tables in gitlab postgresql database ${gitlab_postgresql_db_database}\033[0m"
    echo "delete gitlab postgresql"
    echo
    echo -e "\033[1;36m4. delete all tables in sonarqube postgresql database ${sonarqube_postgresql_db_database}\033[0m"
    echo "delete sonarqube postgresql"
    echo
    echo -e "\033[1;36m5. delete PV, PVC resources\033[0m"
    pvc_count=$(kubectl -n ${namespace} get pvc | grep -E 'gitlab-pv|jenkins-pv|sonarqube-pv' | wc -l)
    if [ ${pvc_count} -gt 0 ];then
        kubectl -n ${namespace} get pvc | grep -E 'gitlab-pvc|jenkins-pvc|sonarqube-pvc|jenkins-slave-pvc' | awk '{print $1}' | while read line
        do
            kubectl -n ${namespace} delete pvc $line
        done
    else
        echo 'no pvc'
    fi
    [ $(kubectl -n ${jenkins_slave_namespace} get pvc | grep -E 'jenkins-slave-pv' | wc -l) -gt 0 ] && { kubectl -n ${jenkins_slave_namespace} delete pvc jenkins-slave-pvc ; } || { echo no jenkins-slave-pvc; }

    pv_count=$(kubectl -n ${namespace} get pv | grep -E 'gitlab-pv|jenkins-pv|sonarqube-pv|jenkins-slave-pv' | wc -l)
    if [ ${pv_count} -gt 0 ];then
        kubectl -n ${namespace} get pv | grep -E 'gitlab-pv|jenkins-pv|sonarqube-pv|jenkins-slave-pv' | awk '{print $1}' | while read line
        do
            kubectl delete pv $line
        done
    else
        echo 'no pv'
    fi

    echo
    sh infra/delete_init_pod.sh
}

echo '
$$$$$$$$\                                     $$$$$$$\                        $$$$$$\                      
$$  _____|                                    $$  __$$\                      $$  __$$\                     
$$ |       $$$$$$\   $$$$$$$\ $$\   $$\       $$ |  $$ | $$$$$$\  $$\    $$\ $$ /  $$ | $$$$$$\   $$$$$$$\ 
$$$$$\     \____$$\ $$  _____|$$ |  $$ |      $$ |  $$ |$$  __$$\ \$$\  $$  |$$ |  $$ |$$  __$$\ $$  _____|
$$  __|    $$$$$$$ |\$$$$$$\  $$ |  $$ |      $$ |  $$ |$$$$$$$$ | \$$\$$  / $$ |  $$ |$$ /  $$ |\$$$$$$\  
$$ |      $$  __$$ | \____$$\ $$ |  $$ |      $$ |  $$ |$$   ____|  \$$$  /  $$ |  $$ |$$ |  $$ | \____$$\ 
$$$$$$$$\ \$$$$$$$ |$$$$$$$  |\$$$$$$$ |      $$$$$$$  |\$$$$$$$\    \$  /    $$$$$$  |$$$$$$$  |$$$$$$$  |
\________| \_______|\_______/  \____$$ |      \_______/  \_______|    \_/     \______/ $$  ____/ \_______/ 
                              $$\   $$ |                                               $$ |                
                              \$$$$$$  |                                               $$ |                
                               \______/                                                \__|                
'

echo '
------------------------------------------------------------------
1. One-keyed DevOps deploy (gitlab, sonarqube, jenkins)
2. Deploy ingress
3. Gitlab upgrade
4. Sonarqube upgrade
5. Jenkins upgrade
6. Delete all resources
------------------------------------------------------------------
'
read -p "please input your choice: " choice

case "${choice}" in
    "1")
        all_deploy
        ;;
    "2")
        deploy_ingress
        ;;
    "3")
        echo "in developing" 
        ;;
    "4")
        echo "in developing" 
        ;;
    "5")
        echo "in developing" 
        ;;
    "6")
        echo -e "\033[31m\033[05mWARNING: THIS OPERATION WILL DELETE THE FOLLOWING RESOURCE!!! \033[0m"
        list_resources
        echo -n -e "\033[31m\033[05mConfirm [Y/N] \033[0m"
        read delete_confirm_first
        [ $(echo ${delete_confirm_first} | grep -Ew 'y|Y' | wc -l) -gt 0 ] || { exit 110; }
        echo -n -e "\033[31m\033[05mThis operation will delete all resources, including database tables, persistent volume data, please be sure to confirm again [Y/N] \033[0m"
        read delete_confirm_second
        [ $(echo ${delete_confirm_second} | grep -Ew 'y|Y' | wc -l) -gt 0 ] && { delete_resources; } || { exit 110; }
        ;;
    *)
        echo "unknow choice" 
		exit 110
        ;;
esac
