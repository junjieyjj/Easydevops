#!groovy
package org.devops
import groovy.transform.Field
// 前置条件，安装ansicolor插件。
// 启用在ansicolor颜色支持方法1：pipeline options中添加颜色配置参数ansiColor('xterm')。
// 启用在ansicolor颜色支持方法2：在Jenkins全局配置ANSI Color->Global color map for all builds配置为xterm。

// 定义全局变量(颜色列表)
@Field String RED = '\033[1;31m'
@Field String YELLOW = '\033[1;33m'
@Field String BLUE = '\033[1;34m'
@Field String GREEN = '\033[1;32m'
@Field String PURPLE = '\033[1;35m'
@Field String NC = '\033[0m'

// 默认使用INFO（蓝色）
def call(body) {
    info (body)
}

// INFO（蓝色）
def info(String msg) {
      println ("${BLUE}INFO: ${msg}${NC}")
}

// WARN（黄色）
def warn(String msg) {
    println ("${YELLOW}WARNING: ${msg}${NC}")
}

// ERROR（红色）
def error(String msg) {
    println ("${RED}ERROR: ${msg}${NC}")
}

// DEBUG（紫色）
def debug(String msg) {
    println ("${PURPLE}DEBUG: ${msg}${NC}")
}

// DONE（绿色）
def done(String msg) {
    println ("${GREEN}DONE: ${msg}${NC}")
}

// Test（ALL）
def test(String msg) {
    println ("${BLUE}INFO: ${msg}${NC}")
    println ("${YELLOW}WARNING: ${msg}${NC}")
    println ("${RED}ERROR: ${msg}${NC}")
    println ("${PURPLE}DEBUG: ${msg}${NC}")
    println ("${GREEN}DONE: ${msg}${NC}")
}