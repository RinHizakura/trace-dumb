#!/usr/bin/env bash
set -e

SYSFS_TRACE=/sys/kernel/debug/tracing
OUTPUT=/tmp/trace_log

function enable_event()
{
    EVENT=$1
    echo write enable to $SYSFS_TRACE/events/$EVENT/enable
    echo 1 > $SYSFS_TRACE/events/$EVENT/enable
}

function print_help()
{
    usage="$(basename "$0") [-h] [-e event] [-p]       \n
where:                                                 \n
    -h  show this help text                            \n
    -e  select the event for ftrace                    \n
    -p  trace only the run command and its childs' PID"

    echo -e $usage
}

if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root user."
    exit 1
fi

EVENT=$SYSFS_TRACE/events
EVENT_LIST=()
PID=0
while getopts ":e:ph" opt
do
    case $opt in
        e)
            EVENT_LIST+=("$OPTARG");;
        p)
            PID=1;;
        h)
            print_help; exit 0;;
        ?)
            print_help; exit 1;;
    esac
done

shift $(($OPTIND - 1))
CMD=$*

if [ "$CMD" == "" ]; then
    print_help
    exit 1
fi

# Clean the trace buffer at start
echo 0 > $SYSFS_TRACE/trace

# Disable the trace first before we setup everything
echo 0 > $SYSFS_TRACE/events/enable
echo 0 > $SYSFS_TRACE/tracing_on

if [[ ${EVENT_LIST[@]} ]]; then
    for ev in ${EVENT_LIST[@]}; do
        echo Enable event $ev
        enable_event $ev
    done
else
    echo Enable all events
    enable_event ""
fi

# Choose the tracer with target setting
echo event-fork > $SYSFS_TRACE/trace_options
echo latency-format > $SYSFS_TRACE/trace_options
echo nop > $SYSFS_TRACE/current_tracer

# Enable trace and start running the command
(sleep 5; $CMD) &
CPID=$!
echo "Run command '$CMD'(ppid=$$ pid=$CPID) and enable tracing..."

# Extra setting to focus on the process from the command
if [[ $PID -eq 1 ]]; then
    # Add child pid to filter to start tracing it
    echo $CPID > $SYSFS_TRACE/set_event_pid
fi

echo 1 > $SYSFS_TRACE/tracing_on
wait $CPID
echo 0 > $SYSFS_TRACE/tracing_on

# Output result
cat $SYSFS_TRACE/trace > $OUTPUT
echo "Done. Please 'sudo cat $OUTPUT' for the result"

# Cleanup the change of ftrace
echo > $SYSFS_TRACE/set_event_pid
echo nop > $SYSFS_TRACE/current_tracer
echo 0 > $SYSFS_TRACE/events/enable
