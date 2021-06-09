#!/usr/bin/bash

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