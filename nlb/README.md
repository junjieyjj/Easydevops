# 使用NLB方式暴露服务

## 1.1、创建ALB Controller IAM策略
> 为了让ALB控制器可以操作AWS ELB资源，需要为其创建IAM策略并赋权，以下采用将权限附加到角色，再将角色附加到节点组来授权。
```bash
# 下载AWS Load Balancer Controller的IAM策略
# 除中国地区以外的所有地区
curl -o iam_policy.json https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v2.1.0/docs/install/iam_policy.json

# 北京和宁夏中国地区
# curl -o iam_policy_cn.json https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v2.1.0/docs/install/iam_policy.json

# 创建AWS Load Balancer Controller的IAM策略
aws iam create-policy \
--policy-name AWSLoadBalancerControllerIAMPolicy \
--policy-document file://iam_policy.json

# 登录AWS IAM控制台，
# 将上面创建的policy添加到当前集群的eks-cluster-NodeRole角色，

```

## 1.2、部署AWS Load Balancer Controller
### 1.2.1、前置条件：部署证书管理器
> AWS Load Balancer Controller部署的前置条件要求部署证书管理器，否则会因为准入条件不符合创建不起来。

```bash
# 部署证书管理器
kubectl apply --validate=false -f https://github.com/jetstack/cert-manager/releases/download/v1.0.2/cert-manager.yaml

# 查看cert-manager相关pod确认正常
kubectl get pod -n cert-manager

```

### 1.2.3、部署ALB控制器

```bash
# 下载ALB YAML
wget https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v2.1.0/docs/install/v2_1_0_full.yaml

# vim编辑yaml修改集群名称为当前集群名称
--cluster-name=<INSERT_CLUSTER_NAME>

# 部署
kubectl apply -f v2_1_0_full.yaml

# 查看部署结果
kubectl get deploy -n kube-system aws-load-balancer-controller

# 查看alb控制器日志（用于debug）
alb_pod=`kubectl get pod -n kube-system | grep aws-load-balancer-controller | awk '{print $1}'`
kubectl logs -f ${alb_pod} -n kube-system

```



## 2.1、部署ingress-nginx controller

```bash
namespace=devops

# 创建tcp-services configmap，使外部可通过git ssh克隆仓库
echo """
apiVersion: v1
data:
  "22": ${namespace}/gitlab:22
  "50000": ${namespace}/jenkins-agent:50000
kind: ConfigMap
metadata:
  name: tcp-services
  namespace: ingress-nginx
""" | kubectl apply -f -

# 创建ingress-nginx-controller
kubectl apply -f ingress-nginx.yaml
```



## 2.2、部署devops ingress

```bash
# 设置组件fqdn
namespace=devops
gitlab_fqdn=gitlab.demo.com
jenkins_fqdn=jenkins.demo.com
sonarqube_fqdn=sonarqube.demo.com

# 创建devops ingress
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

# 查看ingress-nginx-controller service
(base) [root@taiwan-1 nlb]# kubectl -n ingress-nginx get svc ingress-nginx-controller
NAME                       TYPE           CLUSTER-IP       EXTERNAL-IP                                                                     PORT(S)                      AGE
ingress-nginx-controller   LoadBalancer   10.100.214.163   k8s-ingressn-ingressn-390664af6f-decb619c4a690041.elb.ap-east-1.amazonaws.com   80:31043/TCP,443:30486/TCP   29m

# 修改coredns configmap使组件可在集群内部通过fqdn互访
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

# 重启coredns pod
kubectl -n kube-system get pod | grep coredns | awk '{print $1}' | while read line; do kubectl -n kube-system delete pod $line ; done 

# 测试fqdn连通性
[root@ip-192-168-127-215 ~]# curl -l -H "HOST: gitlab.demo.com" http://k8s-ingressn-ingressn-390664af6f-decb619c4a690041.elb.ap-east-1.amazonaws.com

[root@ip-192-168-127-215 ~]# curl -l -H "HOST: jenkins.demo.com" http://k8s-ingressn-ingressn-390664af6f-decb619c4a690041.elb.ap-east-1.amazonaws.com

[root@ip-192-168-127-215 ~]# curl -l -H "HOST: sonarqube.demo.com" http://k8s-ingressn-ingressn-390664af6f-decb619c4a690041.elb.ap-east-1.amazonaws.com
```



