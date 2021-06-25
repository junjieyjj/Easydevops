FROM nginx
LABEL maintainer="john.yu <105951132@qq.com>"

ENV LANG=C.UTF-8 LC_ALL=C.UTF-8

ARG git_hash=unknown
LABEL git.commit.hash=$git_hash


RUN cp /usr/share/zoneinfo/Asia/Shanghai /etc/localtime && \
	echo 'Asia/Shanghai' > /etc/timezone \
    rm -rf /etc/nginx/conf.d/*

WORKDIR /usr/share/nginx/html

COPY ./ ./