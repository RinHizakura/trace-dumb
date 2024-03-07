#!/usr/bin/env bash

CMD=$1
PARM1=$2

SYSFS_TRACE="/sys/kernel/debug/tracing"

case $CMD in
    start)
        sudo sh -c "echo function_graph > $SYSFS_TRACE/current_tracer"
        sudo sh -c "echo funcgraph-tail > $SYSFS_TRACE/trace_options"
        sudo sh -c "echo $PARM1 > $SYSFS_TRACE/set_graph_function"
        sudo sh -c "echo 1 > $SYSFS_TRACE/tracing_on"
        ;;
    filter)
         sudo sh -c "echo $PARM1 > $SYSFS/set_ftrace_filter"
         ;;
    append-filter)
         sudo sh -c "echo $PARM1 >> $SYSFS/set_ftrace_filter"
         ;;
    nofilter)
         sudo sh -c "echo $PARM1 > $SYSFS/set_ftrace_notrace"
         ;;
    append-nofilter)
         sudo sh -c "echo $PARM1 >> $SYSFS/set_ftrace_notrace"
         ;;
    list-func)
        sudo cat $SYSFS/available_filter_functions
        ;;
    report)
        sudo cat $SYSFS/trace
        ;;
    stop)
        sudo sh -c "echo 0 > $SYSFS_TRACE/tracing_on"
        sudo sh -c "echo nop > $SYSFS_TRACE/current_tracer"
        ;;
    clean)
        sudo sh -c "echo 0 > $SYSFS/trace"
        ;;
    *)
        echo "Invalid command $CMD"
        ;;
esac
