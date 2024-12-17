#!/usr/bin/env bash

SYSFS_TRACE=/sys/kernel/debug/tracing
TRACEBOX=./tracebox

if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root user."
    exit 1
fi

while getopts ":c:" opt
do
    case $opt in
        c)
            CFG=$OPTARG;;
        ?)
            exit 1;;
    esac
done

shift $(($OPTIND - 1))
CMD=$*

$TRACEBOX -o trace_file.perfetto-trace --txt -c $CFG &
TPID=$!

(sleep 5;$CMD) &
CPID=$!

echo "Run command '$CMD'(ppid=$$ pid=$CPID) and enable tracing..."
wait $CPID
kill -INT $TPID
echo "Done!"
