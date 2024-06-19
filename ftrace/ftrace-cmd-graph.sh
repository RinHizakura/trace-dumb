#!/usr/bin/env bash

SYSFS_TRACE=/sys/kernel/debug/tracing
OUTPUT=/tmp/trace_log

function root_run()
{
    sudo sh -c "$1"

    ret=$?
    if [ $ret -ne 0 ]
    then
        echo "Run command $1 failed."
        exit 1
    fi
}

FUNC=
TRACE=
NOTRACE=
while getopts ":f:t:n:" opt
do
    case $opt in
        f)
            FUNC=$OPTARG;;
        t)
            TRACE=$OPTARG;;
        n)
            NOTRACE=$OPTARG;;
        ?)
            exit 1;;
    esac
done

shift $(($OPTIND - 1))
CMD=$*

# Clean the trace buffer at start
root_run "echo 0 > $SYSFS_TRACE/trace"

# Disable the trace first before we setup everything
root_run "echo 0 > $SYSFS_TRACE/tracing_on"

# Choose the tracer with target setting
root_run "echo function_graph > $SYSFS_TRACE/current_tracer"
root_run "echo $FUNC > $SYSFS_TRACE/set_graph_function"
root_run "echo $FUNC > $SYSFS_TRACE/set_ftrace_filter"
root_run "echo $TRACE >> $SYSFS_TRACE/set_ftrace_filter"
root_run "echo $NOTRACE > $SYSFS_TRACE/set_ftrace_notrace"
root_run "echo 1 > $SYSFS_TRACE/options/function-fork"
root_run "echo 1 > $SYSFS_TRACE/options/funcgraph-tail"

# Enable trace and start running the command
(sleep 5; $CMD) &
CPID=$!
echo "Run command '$CMD'(ppid=$$ pid=$CPID) and enable tracing..."

# Add child pid to filter to start tracing it
root_run "echo $CPID > $SYSFS_TRACE/set_ftrace_pid"
root_run "echo 1 > $SYSFS_TRACE/tracing_on"
wait $CPID
root_run "echo 0 > $SYSFS_TRACE/tracing_on"

# Output result
root_run "cat $SYSFS_TRACE/trace > $OUTPUT"
echo "Done. Please 'sudo cat $OUTPUT' for the result"

# Cleanup the change of ftrace
root_run "echo > $SYSFS_TRACE/set_ftrace_pid"
root_run "echo 0 > $SYSFS_TRACE/options/funcgraph-tail"
root_run "echo 0 > $SYSFS_TRACE/options/function-fork"
root_run "echo > $SYSFS_TRACE/set_ftrace_notrace"
root_run "echo > $SYSFS_TRACE/set_ftrace_filter"
root_run "echo > $SYSFS_TRACE/set_graph_function"
root_run "echo nop > $SYSFS_TRACE/current_tracer"
