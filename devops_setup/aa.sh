#!/bin/bash

SCRIPT_BASEDIR=$(dirname "$0")

cd ${SCRIPT_BASEDIR}
SCRIPT_BASEDIR="$PWD"

source lib/*

## Test
logger_debug "This is DEBUG level." 
logger_info   "This is INFO level." 
logger_warn   "This is WARN level." 
logger_alert "This is ALERT level." 
logger_fatal "This is FATAL level." 
logger_fatal ""
