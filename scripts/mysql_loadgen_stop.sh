#!/bin/bash
for KILLPID in `ps ax | grep 'mysql_loadgen' | awk '{print $1;}'`; do
kill -9 $KILLPID;
done