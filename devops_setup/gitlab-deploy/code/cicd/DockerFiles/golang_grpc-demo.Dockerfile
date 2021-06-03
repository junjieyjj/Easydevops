FROM golang
LABEL maintainer="john.yu <105951132@qq.com>"

ENV LANG=C.UTF-8 LC_ALL=C.UTF-8

ARG VERSION=$VERSION
ENV VERSION=$VERSION

ARG git_hash=unknown
LABEL git.commit.hash=$git_hash


RUN cp /usr/share/zoneinfo/Asia/Shanghai /etc/localtime && \
    echo 'Asia/Shanghai' > /etc/timezone && \
	mkdir -p /home

WORKDIR /home/

COPY ./target/run /home/

# 数组形式，不支持传参。是由Docker直接运行
# CMD ["/home/run", "-p", "10000", "-v", "5555"]

# 非数组形式，支持传参。是由Docker启动sh，sh再执行命令
CMD /home/run -p 10000 -v $VERSION -s gRPC-Demo