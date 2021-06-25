CURDIR=$(cd $(dirname ${BASH_SOURCE[0]}); pwd )
PROJECT_BASE_DIR=$(dirname ${CURDIR})

echo $PROJECT_BASE_DIR

source ${CURDIR}/utils.sh
source ${PROJECT_BASE_DIR}/k8s/utils.sh

test_green(){
    echo_green 1111
}

