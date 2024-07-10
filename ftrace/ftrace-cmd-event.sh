#!/usr/bin/env bash
set -e

SYSFS_TRACE=/sys/kernel/debug/tracing
OUTPUT=/tmp/trace_log

if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root user."
    exit 1
fi

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
echo 0 > $SYSFS_TRACE/trace

# Disable the trace first before we setup everything
echo 0 > $SYSFS_TRACE/events/enable
echo 0 > $SYSFS_TRACE/tracing_on

# Choose the tracer with target setting
echo 1 >  $EVENT/enable
echo event-fork > $SYSFS_TRACE/trace_options
echo latency-format > $SYSFS_TRACE/trace_options
echo nop > $SYSFS_TRACE/current_tracer

# Enable trace and start running the command
(sleep 5; $CMD) &
CPID=$!
echo "Run command '$CMD'(ppid=$$ pid=$CPID) and enable tracing..."

# Add child pid to filter to start tracing it
echo $CPID > $SYSFS_TRACE/set_event_pid
echo 1 > $SYSFS_TRACE/tracing_on
wait $CPID
echo 0 > $SYSFS_TRACE/tracing_on

# Output result
cat $SYSFS_TRACE/trace > $OUTPUT
echo "Done. Please 'sudo cat $OUTPUT' for the result"

# Cleanup the change of ftrace
echo > $SYSFS_TRACE/set_event_pid
echo nop > $SYSFS_TRACE/current_tracer
echo nolatency-format > $SYSFS_TRACE/trace_options
echo noevent-fork > $SYSFS_TRACE/trace_options
echo 0 >  $EVENT/enable
