FROM node:latest
LABEL maintainer="john.yu <105951132@qq.com>"

ENV LANG=C.UTF-8 LC_ALL=C.UTF-8

ARG git_hash=unknown
LABEL git.commit.hash=$git_hash

USER root

WORKDIR /usr/src/app/

COPY ./ ./

RUN npm config set registry http://registry.cnpmjs.org && \
    chmod -R 777 * && \
    npm install --silent --no-cache 

CMD ["npm", "run", "start"]
