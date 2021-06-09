#!/usr/bin/bash
SCRIPT_BASEDIR=$(dirname "$0")

cd ${SCRIPT_BASEDIR}
SCRIPT_BASEDIR="$PWD"

# include lib
source lib/*


all_deploy() {
    # Create EFS persistent volume and persistent volume claim
    echo_yellow "Stage0. create EFS persistent volume and persistent volume claim"
    sh infra/run.sh
    revalue=$?
    if [[ "${revalue}" == 110 ]]
    then
        exit 1
    fi
    echo_yellow "Stage0 done.."
    echo

    # Deploy Gitlab 
    echo_yellow "Stage1. deploy gitlab componment"
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
    echo_yellow "Stage1 done.."
    echo

    # Deploy Sonarqube
    echo_yellow "Stage2. deploy sonarqube componment"
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
    echo_yellow "Stage2 done.."
    sonarqube_api_token=$(cat init/sonarqube-api-token)

    # Deploy Jenkins
    echo_yellow "Stage3. deploy jenkins componment"
    sh jenkins-deploy/run.sh
    revalue=$?
    if [[ "${revalue}" == 110 ]]
    then
        exit 1
    fi
    echo_yellow "Stage3 done.."
    echo

    # Deploy ingress
    echo_yellow "Stage4. deploy ingress componment"
    sh nlb/run.sh
    revalue=$?
    if [[ "${revalue}" == 110 ]]
    then
        exit 1
    fi
    echo_yellow "Stage4 done.."
}

echo 'Easy DevOps
------------------------------------------------------------------
1. One-keyed DevOps deploy (gitlab, sonarqube, jenkins)
2. Gitlab upgrade
3. Sonarqube upgrade
4. Jenkins upgrade
------------------------------------------------------------------
'
read -p "please give me your choice: " choice

case "${choice}" in
    "1")
        all_deploy
        ;;
    "2")
        echo "in developing" 
        ;;
    "3")
        echo "in developing" 
        ;;
    "4")
        echo "in developing" 
        ;;
    *)
        echo "unknow choice" 
		exit 110
        ;;
esac
