#! /bin/bash
# Version 2.0

MYSQL_USER=$1
MYSQL_USER_PWD=$2

if [ -z "$1" ] ; then
  printf "LB URL not set, exiting ...\n"
  exit 1
else
  printf "LB URL Variable Detected...\n"
fi

echo MYSQL_USER=$MYSQL_USER >> /etc/otel/collector/splunk-otel-collector.conf
echo MYSQL_USER_PWD=$MYSQL_USER_PWD >> /etc/otel/collector/splunk-otel-collector.conf