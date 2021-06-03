
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
    image: "216059448262.dkr.ecr.ap-east-1.amazonaws.com/devops/jenkins-slave-cd:v47"
    imagePullPolicy: "IfNotPresent"
    tty: true
    volumeMounts:
    - mountPath: "/var/run/docker.sock"
      name: "volume-0"
      readOnly: false 
    - mountPath: "/home/jenkins/.docker"
      name: "docker-cache"
    - mountPath: "/root/.m2"
      name: "volume-1"
      readOnly: false
      subPath: "jenkins-slave/maven_cache/m2"
    workingDir: /home/jenkins/agent 
  volumes:
  - hostPath:
      path: "/var/run/docker.sock"
    name: "volume-0"
  - name: docker-cache
    emptyDir: {}
  - name: "volume-1"
    persistentVolumeClaim:
      claimName: "jenkins-slave-pvc"
      readOnly: false
  - emptyDir:
      medium: ""
    name: "workspace-volume"
"""
	return ci;
}
