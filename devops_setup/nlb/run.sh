#!/usr/bin/bash
SCRIPT_BASEDIR=$(dirname "$0")

cd ${SCRIPT_BASEDIR}
SCRIPT_BASEDIR="$PWD"
PROJECT_BASEDIR=$(dirname "${SCRIPT_BASEDIR}")

# load env config
source ${SCRIPT_BASEDIR}/config
source ${PROJECT_BASEDIR}/jenkins-deploy/config

# deploy alb controller
echo "step1. Deploy alb controller"

sed "s/INSERT_CLUSTER_NAME/${cluster_name}/g" v2_1_0_full.yaml.template > v2_1_0_full.yaml

kubectl apply --validate=false -f https://github.com/jetstack/cert-manager/releases/download/v1.0.2/cert-manager.yaml

kubectl apply -f v2_1_0_full.yaml

echo
echo "step2. Deploy ingress nginx controller"
echo """
apiVersion: v1
data:
  "22": ${namespace}/gitlab:22
kind: ConfigMap
metadata:
  name: tcp-services
  namespace: ingress-nginx
""" | kubectl apply -f -

kubectl apply -f ingress-nginx.yaml

echo
echo "step3. Deploy devops ingress resources"
echo """
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  name: devops
  namespace: ${namespace}
  annotations:
    nginx.ingress.kubernetes.io/proxy-body-size: "1000M"
spec:
  rules:
  - host: ${gitlab_fqdn}
    http:
      paths:
      - backend:
          serviceName: gitlab
          servicePort: 80
        path: /
  - host: ${jenkins_fqdn}
    http:
      paths:
      - backend:
          serviceName: jenkins
          servicePort: 8080
        path: /
  - host: ${sonarqube_fqdn}
    http:
      paths:
      - backend:
          serviceName: sonarqube-sonarqube
          servicePort: 9000
        path: /
""" | kubectl apply -f -

