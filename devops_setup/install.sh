#!/usr/bin/bash

# Create EFS persistent volume and persistent volume claim
echo "Stage0. create EFS persistent volume and persistent volume claim"
sh infra/run.sh
echo "Stage0 done.."
echo

# Deploy Gitlab 
echo "Stage1. deploy gitlab componment"
sh gitlab-deploy/run.sh
sh init/init_gitlab.sh
echo "Stage1 done.."
echo

# Deploy Sonarqube
echo "Stage2. deploy sonarqube componment"
sh sonarqube-deploy/run.sh
sh init_sonarqube.sh
echo "Stage2 done.."

# Deploy Jenkins
echo "Stage3. deploy jenkins componment"
sh jenkins-deploy/run.sh
echo "Stage3 done.."

# Deploy ingress
echo "Stage4. deploy ingress componment"
sh nlb/run.sh
echo "Stage4 done.."