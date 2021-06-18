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

all_deploy() {
    # Create EFS persistent volume and persistent volume claim
    logger_info "Stage0. create EFS persistent volume and persistent volume claim"
    sh infra/run.sh
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
    echo -e "\033[1;36m1. Helm Release:\033[0m"
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
    kubectl -n ${namespace} get pv | grep -E 'gitlab-pv|jenkins-pv|sonarqube-pv|jenkins-slave-pv'
    echo
    echo 'NAME            STATUS   VOLUME         CAPACITY   ACCESS MODES   STORAGECLASS   AGE'
    kubectl -n ${namespace} get pvc | grep -E 'gitlab-pv|jenkins-pv|sonarqube-pv|jenkins-slave-pv'
    echo
    
}

delete_resources(){
    echo ''
}

echo 'Easy DevOps
------------------------------------------------------------------
1. One-keyed DevOps deploy (gitlab, sonarqube, jenkins)
2. Deploy ingress
3. Gitlab upgrade
4. Sonarqube upgrade
5. Jenkins upgrade
6. Delete all resources
------------------------------------------------------------------
'
read -p "please give me your choice: " choice

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
        echo -e "\033[31m\033[05mConfirm [Y/N] \033[0m"
        ;;
    *)
        echo "unknow choice" 
		exit 110
        ;;
esac
