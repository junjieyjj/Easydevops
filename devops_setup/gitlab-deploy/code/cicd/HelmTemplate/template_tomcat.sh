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
    - name: http-tomcat
      port: 8080
      targetPort: 8080
      protocol: TCP
  selector:
    app: ${APP_NAME}
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ${APP_NAME}
  namespace: ${NAMESPACE}
  labels:
    app: ${APP_NAME}
    version: "${BUILD_TAG_NAME}"
    gitcommit: ${GIT_COMMIT}
spec:
  revisionHistoryLimit: 5
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
    spec:
      containers:
      - name: ${APP_NAME}
        image: ${RemoteRegistry}/${APP_NAME}:${BUILD_TAG_NAME}
        imagePullPolicy: Always
        env:
        - name: MY_CONTAINER_IP
          valueFrom:
            fieldRef:
              fieldPath: status.podIP
        - name: MY_POD_NAMESPACE
          valueFrom:
            fieldRef:
              fieldPath: metadata.namespace
        - name: MY_POD_NAME
          valueFrom:
            fieldRef:
              fieldPath: metadata.name
        - name: NODE_NAME
          valueFrom:
            fieldRef:
              fieldPath: spec.nodeName

        - name: aliyun_logs_tomcatlog
          value: "/usr/local/tomcat/logs/*.log"
        - name: aliyun_logs_tomcatlog_tags
          value: | 
            environment_type=\$(MY_POD_NAMESPACE),
            business_name=${project},
            application_name=${APP_NAME},
            container_ip=\$(MY_CONTAINER_IP),
            machine_name=\$(NODE_NAME),
            file_type_name=tomcat_log

        - name: aliyun_logs_javalog
          value: "/logs/*.log"
        - name: aliyun_logs_javalog_tags
          value: | 
            environment_type=\$(MY_POD_NAMESPACE),
            business_name=${project},
            application_name=${APP_NAME},
            container_ip=\$(MY_CONTAINER_IP),
            machine_name=\$(NODE_NAME),
            file_type_name=java_app_log

        - name: deployenv
          value: ${NAMESPACE}
        envFrom:
        - configMapRef:
            name: ${APP_NAME}-env

        ports:
        - name: http-tomcat
          containerPort: 8080
          protocol: TCP

        volumeMounts:
        - name: logs
          mountPath: /logs
        - name: tomcat-log
          mountPath: /usr/local/tomcat/logs/
        - name: config
          mountPath: /configs/

        livenessProbe:
          httpGet:
            path: /ping
            port: 8080
          #initialDelaySeconds: 20
          periodSeconds: 10
          timeoutSeconds: 3
          failureThreshold: 3
          successThreshold: 1
        readinessProbe:
          httpGet:
            path: /ping
            port: 8080
          #initialDelaySeconds: 20
          periodSeconds: 10
          timeoutSeconds: 3
          failureThreshold: 3
          successThreshold: 1
      #nodeSelector:
        #env: ${NAMESPACE}

      volumes:
      - name: logs
        emptyDir: {}
      - name: tomcat-log
        emptyDir: {}
      - name: config
        configMap:
          name: ${APP_NAME}-conf
EOF