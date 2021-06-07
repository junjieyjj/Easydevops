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

echo
echo "step4. Renew coredns configmap and restart pod"
echo """
apiVersion: v1
data:
  Corefile: |
    .:53 {
        errors
        health
        kubernetes cluster.local in-addr.arpa ip6.arpa {
          pods insecure
          fallthrough in-addr.arpa ip6.arpa
        }
        rewrite name ${gitlab_fqdn} ingress-nginx-controller.ingress-nginx.svc.cluster.local
        rewrite name ${jenkins_fqdn} ingress-nginx-controller.ingress-nginx.svc.cluster.local
        rewrite name ${sonarqube_fqdn} ingress-nginx-controller.ingress-nginx.svc.cluster.local
        prometheus :9153
        forward . /etc/resolv.conf
        cache 30
        loop
        reload
        loadbalance
    }
kind: ConfigMap
metadata:
  labels:
    eks.amazonaws.com/component: coredns
    k8s-app: kube-dns
  name: coredns
  namespace: kube-system
""" | kubectl apply -f -

kubectl -n kube-system get pod | grep coredns | awk '{print $1}' | while read line; do kubectl -n kube-system delete pod $line ; done 