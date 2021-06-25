FROM openjdk:8u242
LABEL maintainer="john.yu <105951132@qq.com>"

ENV LANG=C.UTF-8 LC_ALL=C.UTF-8

ARG git_hash=unknown
LABEL git.commit.hash=$git_hash

RUN cp /usr/share/zoneinfo/Asia/Shanghai /etc/localtime && \
	echo 'Asia/Shanghai' > /etc/timezone

COPY ./target/*.jar /java/app.jar

WORKDIR /java

EXPOSE 18081

ENTRYPOINT ["/bin/sh","-c","exec java $JVM_OPTS -jar app.jar $APP_OPTS"]