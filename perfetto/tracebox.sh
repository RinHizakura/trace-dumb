#!/usr/bin/env bash

set -e

SYSFS_TRACE=/sys/kernel/debug/tracing
TRACEBOX=./tracebox

function print_help()
{
    usage="$(basename "$0") [-h] [-c config] cmdline   \n
where:                                                 \n
    -h  show this help text                            \n
    -c  select the config for tracebox"

    echo -e $usage
}

if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root user."
    exit 1
fi

while getopts ":c:" opt
do
    case $opt in
        c)
            CFG=$OPTARG;;
        h)
            print_help; exit 0;;
        ?)
            print_help; exit 1;;
    esac
done

shift $(($OPTIND - 1))
CMD=$*

if [ ! -f "$TRACEBOX" ]; then
    echo "'$TRACEBOX' does not exist"
    exit 1
fi

if [ -z "$CFG" ]; then
    echo "Config '$CFG' does not exist"
    print_help
    exit 1
fi

if [ "$CMD" == "" ]; then
    echo "Please specific the command to run"
    print_help
    exit 1
fi

$TRACEBOX -o trace_file.perfetto-trace --txt -c $CFG &
TPID=$!

(sleep 5;$CMD) &
CPID=$!

echo "Run command '$CMD'(ppid=$$ pid=$CPID) and enable tracing..."
wait $CPID
kill -INT $TPID
echo "Done!"
