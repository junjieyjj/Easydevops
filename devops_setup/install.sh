#!/usr/bin/bash
SCRIPT_BASEDIR=$(dirname "$0")

cd ${SCRIPT_BASEDIR}
SCRIPT_BASEDIR="$PWD"

# include lib
source lib/*


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
