def call() {
	def ci = """
apiVersion: v1
kind: Pod
metadata:
  namespace: jenkins-slave
  labels:
    jenkins: slave
    jenkins/ci: "true"
spec:
  containers:
  - name: "jnlp"
    image: "216059448262.dkr.ecr.ap-east-1.amazonaws.com/devops/jenkins-slave-ci:v13"  
    imagePullPolicy: "IfNotPresent"
    tty: true
    volumeMounts:
    - mountPath: "/var/run/docker.sock"
      name: "volume-0"
      readOnly: false 
    - mountPath: "/home/jenkins/.docker"
      name: "docker-cache"
    - mountPath: "/var/jenkins_home/amwaybuild"
      name: "volume-1"
      readOnly: false
      subPath: "jenkins-slave/data"
    - mountPath: "/home/jenkins/.npm"
      name: "volume-1"
      readOnly: false
      subPath: "jenkins-slave/npm_cache/npm"
    - mountPath: "/root/.m2"
      name: "volume-1"
      readOnly: false
      subPath: "jenkins-slave/maven_cache/m2"
    - name: cache-jacoco-maven-plugin
      mountPath: /root/.m2/repository/org/jacoco/jacoco-maven-plugin
    workingDir: /home/jenkins/agent
  volumes:
  - hostPath:
      path: "/var/run/docker.sock"
    name: "volume-0"
  - name: "volume-1"
    persistentVolumeClaim:
      claimName: "jenkins-slave-pvc"
      readOnly: false
  - emptyDir:
      medium: ""
    name: "workspace-volume"      
  - name: cache-jacoco-maven-plugin
    emptyDir: {}
  - name: docker-cache
    emptyDir: {}
"""
	return ci;
}
