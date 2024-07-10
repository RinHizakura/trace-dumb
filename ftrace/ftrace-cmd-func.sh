#!/usr/bin/env bash

SYSFS_TRACE=/sys/kernel/debug/tracing
OUTPUT=/tmp/trace_log

if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root user."
    exit 1
fi

FUNC=
TRACE=
NOTRACE=
TRACER=function
while getopts ":f:t:n:T:" opt
do
    case $opt in
        f)
            FUNC=$OPTARG;;
        t)
            TRACE=$OPTARG;;
        n)
            NOTRACE=$OPTARG;;
        T)
            TRACER=$OPTARG;;
        ?)
            exit 1;;
    esac
done

shift $(($OPTIND - 1))
CMD=$*


# Clean the trace buffer at start
echo 0 > $SYSFS_TRACE/trace

# Disable the trace first before we setup everything
echo 0 > $SYSFS_TRACE/tracing_on

# Choose the tracer with target setting
echo $TRACER > $SYSFS_TRACE/current_tracer
echo $FUNC > $SYSFS_TRACE/set_graph_function
echo $FUNC > $SYSFS_TRACE/set_ftrace_filter
echo $TRACE >> $SYSFS_TRACE/set_ftrace_filter
echo $NOTRACE > $SYSFS_TRACE/set_ftrace_notrace
echo 1 > $SYSFS_TRACE/options/function-fork
echo 1 > $SYSFS_TRACE/options/funcgraph-tail

# Enable trace and start running the command
(sleep 5; $CMD) &
CPID=$!
echo "Run command '$CMD'(ppid=$$ pid=$CPID) and enable tracing..."

# Add child pid to filter to start tracing it
echo $CPID > $SYSFS_TRACE/set_ftrace_pid
echo 1 > $SYSFS_TRACE/tracing_on
wait $CPID
echo 0 > $SYSFS_TRACE/tracing_on

# Output result
cat $SYSFS_TRACE/trace > $OUTPUT
echo "Done. Please 'sudo cat $OUTPUT' for the result"

# Cleanup the change of ftrace
echo > $SYSFS_TRACE/set_ftrace_pid
echo 0 > $SYSFS_TRACE/options/funcgraph-tail
echo 0 > $SYSFS_TRACE/options/function-fork
echo > $SYSFS_TRACE/set_ftrace_notrace
echo > $SYSFS_TRACE/set_ftrace_filter
echo > $SYSFS_TRACE/set_graph_function
echo nop > $SYSFS_TRACE/current_tracer
