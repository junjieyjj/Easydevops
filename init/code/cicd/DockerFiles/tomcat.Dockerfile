FROM tomcat:8.5.8
LABEL maintainer="john.yu <105951132@qq.com>"

ENV LANG=C.UTF-8 LC_ALL=C.UTF-8

ARG git_hash=unknown
LABEL git.commit.hash=$git_hash


RUN cp /usr/share/zoneinfo/Asia/Shanghai /etc/localtime && \
    echo 'Asia/Shanghai' > /etc/timezone && \
    sed -i 's/Connector port="8080"/Connector port="8080" URIEncoding="UTF-8"/' conf/server.xml && \
    sed -i 's/<Context>/<Context sessionCookieName="${cookie.name}">/' conf/server.xml && \
    sed -i 's/SHUTDOWN/HZHuQhfnW/' /usr/local/tomcat/conf/server.xml && \
	useradd tomcat && \
	chown tomcat:tomcat -R /usr/local/tomcat && \
	rm -rf webapps/*

USER tomcat
WORKDIR /usr/local/tomcat

COPY ./target/*.war webapps/ROOT.war