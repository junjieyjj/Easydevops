# 获取脚本所在目录完整路径
project_path=$(cd `dirname $0`; pwd)

# 渲染生成部署文件
cat > $project_path/deploy.yaml << EOF
apiVersion: v1
kind: Service
metadata:
  name: ${SERVICE_NAME}
  namespace: ${NAMESPACE}
spec:
  type: ClusterIP
  ports:
    - name: http
      port: 80
      targetPort: 80
      protocol: TCP
  selector:
    app: ${APP_NAME}
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ${APP_NAME}-${VERSION}
  namespace: ${NAMESPACE}
  labels:
    app: ${APP_NAME}
    version: ${VERSION}
    build_tag: ${BUILD_TAG}
    gitcommit: ${GIT_COMMIT}
spec:
  revisionHistoryLimit: 0
  replicas: ${REPLICAS}
  selector:
    matchLabels:
      app: ${APP_NAME}
  #minReadySeconds: 10
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 0

  template:
    metadata:
      labels:
        app: ${APP_NAME}
        version: "${VERSION}"
    spec:
      containers:
      - name: ${APP_NAME}
        image: ${RemoteRegistry}/${APP_NAME}:${BUILD_TAG}
        imagePullPolicy: Always
        env:
        - name: deployenv
          value: ${NAMESPACE}
        ports:
        - name: http-nginx
          containerPort: 80
          protocol: TCP
        livenessProbe:
          httpGet:
            path: /
            port: 80
          #initialDelaySeconds: 3
          periodSeconds: 2
          timeoutSeconds: 3
          failureThreshold: 3
          successThreshold: 1
        readinessProbe:
          httpGet:
            path: /
            port: 80
          #initialDelaySeconds: 3
          periodSeconds: 2
          timeoutSeconds: 3
          failureThreshold: 3
          successThreshold: 1
      #nodeSelector:
        #env: ${NAMESPACE}
EOF