#!/usr/bin/env bash

CMD=$@
SYSFS_TRACE=/sys/kernel/debug/tracing
OUTPUT=/tmp/trace_log

function root_run()
{
    sudo sh -c "$1"

    ret=$?
    if [ $ret -eq 1 ]
    then
        echo "Run command $1 failed."
        exit 1
    fi
}

EVENT=$SYSFS_TRACE/events
while getopts ":e:" opt
do
    case $opt in
        e)
            EVENT=$SYSFS_TRACE/events/$OPTARG;;
        ?)
            exit 1;;
    esac
done

shift $(($OPTIND - 1))
CMD=$*


# Clean the trace buffer at start
root_run "echo 0 > $SYSFS_TRACE/trace"

# Disable the trace first before we setup everything
root_run "echo 0 >  $SYSFS_TRACE/events/enable"
root_run "echo 0 > $SYSFS_TRACE/tracing_on"

# Choose the tracer with target setting
root_run "echo 1 >  $EVENT/enable"
root_run "echo event-fork > $SYSFS_TRACE/trace_options"
root_run "echo latency-format > $SYSFS_TRACE/trace_options"
root_run "echo nop > $SYSFS_TRACE/current_tracer"

# Enable trace and start running the command
(sleep 5; $CMD) &
CPID=$!
echo "Run command '$CMD'(ppid=$$ pid=$CPID) and enable tracing..."

# Add child pid to filter to start tracing it
root_run "echo $CPID > $SYSFS_TRACE/set_event_pid"
root_run "echo 1 > $SYSFS_TRACE/tracing_on"
wait $CPID
root_run "echo 0 > $SYSFS_TRACE/tracing_on"

# Output result
root_run "cat $SYSFS_TRACE/trace > $OUTPUT"
echo "Done. Please 'sudo cat $OUTPUT' for the result"

# Cleanup the change of ftrace
root_run "echo > $SYSFS_TRACE/set_event_pid"
root_run "echo nop > $SYSFS_TRACE/current_tracer"
root_run "echo nolatency-format > $SYSFS_TRACE/trace_options"
root_run "echo noevent-fork > $SYSFS_TRACE/trace_options"
root_run "echo 0 >  $EVENT/enable"
