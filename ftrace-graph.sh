#!/usr/bin/env bash

CMD=$1
PARM1=$2

case $CMD in
    start)
        sudo sh -c "echo function_graph > /sys/kernel/debug/tracing/current_tracer"
        sudo sh -c "echo funcgraph-tail > /sys/kernel/debug/tracing/trace_options"
        sudo sh -c "echo $PARM1 > /sys/kernel/debug/tracing/set_graph_function"
        sudo sh -c "echo 1 > /sys/kernel/debug/tracing/tracing_on"
        ;;
    filter)
         sudo sh -c "echo $PARM1 > /sys/kernel/debug/tracing/set_ftrace_filter"
         ;;
    append-filter)
         sudo sh -c "echo $PARM1 >> /sys/kernel/debug/tracing/set_ftrace_filter"
         ;;
    list-func)
        sudo cat /sys/kernel/debug/tracing/available_filter_functions
        ;;
    report)
        sudo cat /sys/kernel/debug/tracing/trace
        ;;
    stop)
        sudo sh -c "echo 0 > /sys/kernel/debug/tracing/tracing_on"
        sudo sh -c "echo nop > /sys/kernel/debug/tracing/current_tracer"
        ;;
    clean)
        sudo sh -c "echo 0 > /sys/kernel/debug/tracing/trace"
        ;;
    *)
        echo "Invalid command $CMD"
        ;;
esac
