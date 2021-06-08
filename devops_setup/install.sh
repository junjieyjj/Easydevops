#!/usr/bin/bash
SCRIPT_BASEDIR=$(dirname "$0")

cd ${SCRIPT_BASEDIR}
SCRIPT_BASEDIR="$PWD"

# include lib
source lib/*

# Create EFS persistent volume and persistent volume claim
echo_light_cyan "Stage0. create EFS persistent volume and persistent volume claim"
sh infra/run.sh
revalue=$?
if [[ "${revalue}" == 110 ]]
then
	exit 1
fi
echo_light_cyan "Stage0 done.."
echo

# Deploy Gitlab 
echo_light_cyan "Stage1. deploy gitlab componment"
sh gitlab-deploy/run.sh
sh init/init_gitlab.sh
echo_light_cyan "Stage1 done.."
echo

# Deploy Sonarqube
echo_light_cyan "Stage2. deploy sonarqube componment"
sh sonarqube-deploy/run.sh
sh init/init_sonarqube.sh
echo_light_cyan "Stage2 done.."

# Deploy Jenkins
echo_light_cyan "Stage3. deploy jenkins componment"
sh jenkins-deploy/run.sh
echo_light_cyan "Stage3 done.."
echo

# Deploy ingress
echo_light_cyan "Stage4. deploy ingress componment"
sh nlb/run.sh
echo_light_cyan "Stage4 done.."