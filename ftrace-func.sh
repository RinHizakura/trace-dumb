#!/usr/bin/env bash

CMD=$1
PARM1=$2

SYSFS_TRACE="/sys/kernel/debug/tracing"

case $CMD in
    start)
        sudo sh -c "echo function > $SYSFS_TRACE/current_tracer"
        sudo sh -c "echo $PARM1 > $SYSFS_TRACE/set_ftrace_filter"
        sudo sh -c "echo 1 > $SYSFS_TRACE/tracing_on"
        ;;
    add)
         sudo sh -c "echo $PARM1 >> $SYSFS_TRACE/set_ftrace_filter"
         ;;
    stack)
        sudo sh -c "echo stacktrace > $SYSFS_TRACE/trace_options"
        ;;
    latency)
        sudo sh -c "echo latency-format > $SYSFS_TRACE/trace_options"
        ;;
    list-func)
        sudo cat $SYSFS_TRACE/available_filter_functions
        ;;
    report)
        sudo cat $SYSFS_TRACE/trace
        ;;
    stop)
        sudo sh -c "echo 0 > $SYSFS_TRACE/tracing_on"
        sudo sh -c "echo nop > $SYSFS_TRACE/current_tracer"
        ;;
    clean)
        sudo sh -c "echo 0 > $SYSFS_TRACE/trace"
        ;;
    *)
        echo "Invalid command $CMD"
        ;;
esac
