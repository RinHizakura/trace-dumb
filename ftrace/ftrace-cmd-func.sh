#!/usr/bin/env bash

function try_write()
{
    FILE_PATH=$1
    CONTENT=$2

    ls $FILE_PATH >> /dev/null 2>&1 && echo $CONTENT > $FILE_PATH
}

function print_help()
{
    usage="$(basename "$0") [-h] [-f func] [-t trace] [-n notrace] [-T tracer] [-p] [-s]  \n
where:                                                                                    \n
    -h  show this help text                                                               \n
    -f  select the function if using funcgraph tracer                                     \n
    -t  select the filter for function to be traced                                       \n
    -n  select the filter for function to not be traced                                   \n
    -T  select the tracer                                                                 \n
    -p  trace only the run command and its childs' PID                                    \n
    -s  show stack trace for the trace"

    echo -e $usage
}

SYSFS_TRACE=/sys/kernel/debug/tracing
OUTPUT=/tmp/trace_log

if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root user."
    exit 1
fi

FUNC=
TRACE_LIST=()
NOTRACE_LIST=()
PID=0
STACK=0
TRACER=function
while getopts ":f:t:n:T:psh" opt
do
    case $opt in
        f)
            FUNC=$OPTARG;;
        t)
            TRACE_LIST+=("$OPTARG");;
        n)
            NOTRACE_LIST+=("$OPTARG");;
        T)
            TRACER=$OPTARG;;
        p)
            PID=1;;
        s)
            STACK=1;;
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
echo 0 > $SYSFS_TRACE/tracing_on

# Choose the tracer with target setting
echo $TRACER > $SYSFS_TRACE/current_tracer
echo "$FUNC" > $SYSFS_TRACE/set_graph_function

echo > $SYSFS_TRACE/set_ftrace_filter
if [[ ${TRACE_LIST[@]} ]]; then
    echo "$FUNC" > $SYSFS_TRACE/set_ftrace_filter
    for f in ${TRACE_LIST[@]}; do
        echo $f >> $SYSFS_TRACE/set_ftrace_filter
    done
fi

echo > $SYSFS_TRACE/set_ftrace_notrace
if [[ ${NOTRACE_LIST[@]} ]]; then
    for f in ${NOTRACE_LIST[@]}; do
        echo $f >> $SYSFS_TRACE/set_ftrace_notrace
    done
fi

try_write $SYSFS_TRACE/options/funcgraph-tail 1
try_write $SYSFS_TRACE/options/funcgraph-retval 1
echo $STACK > $SYSFS_TRACE/options/func_stack_trace
echo latency-format > $SYSFS_TRACE/trace_options

# Enable trace and start running the command
(sleep 5; $CMD) &
CPID=$!
echo "Run command '$CMD'(ppid=$$ pid=$CPID) and enable tracing..."

# Extra setting to focus on the process from the command
if [[ $PID -eq 1 ]]; then
    # Add child pid to filter to start tracing it
    echo $CPID > $SYSFS_TRACE/set_ftrace_pid
    echo 1 > $SYSFS_TRACE/options/function-fork
fi

echo 1 > $SYSFS_TRACE/tracing_on
wait $CPID
echo 0 > $SYSFS_TRACE/tracing_on

# Output result
cat $SYSFS_TRACE/trace > $OUTPUT
echo "Done. Please 'sudo cat $OUTPUT' for the result"

# Cleanup the change of ftrace
echo > $SYSFS_TRACE/set_ftrace_pid
echo > $SYSFS_TRACE/set_ftrace_notrace
echo > $SYSFS_TRACE/set_ftrace_filter
echo > $SYSFS_TRACE/set_graph_function
echo nop > $SYSFS_TRACE/current_tracer
