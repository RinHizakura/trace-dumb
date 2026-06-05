#!/usr/bin/env bash

function print_help()
{
    usage="$(basename "$0") [-h] [-T tracer] [-l latency] [-p] <command>  \n
where:                                                                    \n
    -h  show this help text                                               \n
    -T  select the tracer: irqsoff, preemptoff (default: irqsoff)        \n
    -l  set the latency threshold in us (default: 0)                      \n
    -p  trace only the run command and its childs' PID"

    echo -e $usage
}

SYSFS_TRACE=/sys/kernel/debug/tracing
OUTPUT=/tmp/trace_log

if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root user."
    exit 1
fi

PID=0
LATENCY=0
TRACER=irqsoff
while getopts ":T:l:ph" opt
do
    case $opt in
        T)
            TRACER=$OPTARG;;
        l)
            LATENCY=$OPTARG;;
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

# Clean the trace buffer and reset max latency at start
echo 0 > $SYSFS_TRACE/trace
echo $LATENCY > $SYSFS_TRACE/tracing_max_latency

# Disable the trace first before we setup everything
echo 0 > $SYSFS_TRACE/tracing_on

# Choose the tracer
echo $TRACER > $SYSFS_TRACE/current_tracer

# Enable trace and start running the command
(sleep 5; $CMD) &
CPID=$!
echo "Run command '$CMD'(ppid=$$ pid=$CPID) and enable tracing..."

# Extra setting to focus on the process from the command
if [[ $PID -eq 1 ]]; then
    echo $CPID > $SYSFS_TRACE/set_ftrace_pid
    echo 1 > $SYSFS_TRACE/options/function-fork
fi

echo 1 > $SYSFS_TRACE/tracing_on
wait $CPID
echo 0 > $SYSFS_TRACE/tracing_on

# Output result
cat $SYSFS_TRACE/trace > $OUTPUT
echo "Max $TRACER latency: $(cat $SYSFS_TRACE/tracing_max_latency) us"
echo "Done. Please 'sudo cat $OUTPUT' for the result"

# Cleanup the change of ftrace
echo > $SYSFS_TRACE/set_ftrace_pid
echo nop > $SYSFS_TRACE/current_tracer
