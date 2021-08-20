#!/usr/bin/bash

# 字体颜色
RED="\e[31m"
GREEN="\e[32m"
CYAN="\e[34m"
YELLOW="\e[33m"
ENDCOLOR="\e[0m"

echo_green(){
  echo -e "${GREEN}${1} ${ENDCOLOR}"
}

echo_red(){
  echo -e "${RED}${1} ${ENDCOLOR}"
}

echo_cyan(){
    echo -e "${CYAN}${1} ${ENDCOLOR}"
}

echo_yellow(){
    echo -e "${YELLOW}${1} ${ENDCOLOR}"
}

