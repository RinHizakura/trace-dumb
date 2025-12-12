#!/usr/bin/env bash

set -e

function print_help()
{
    usage="$(basename "$0") -d deivce [-h]             \n
where:                                                 \n
    -d  specific the device for blktrace               \n
    -h  show this help text"

    echo -e $usage
}

if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root user."
    exit 1
fi

while getopts ":d:h" opt
do
    case $opt in
        d)
            DEV=$OPTARG;;
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

if [ -z $DEV ]; then
    echo "Please specific the block device for tracing"
    print_help
    exit 1
fi

BLKTRACE_CMD="blktrace -d $DEV -o blktrace_out"

echo Run: $CMD
$CMD &
CPID=$!

echo Run: $BLKTRACE_CMD
$BLKTRACE_CMD &
BPID=$!

wait $CPID

echo "Complete I/O operation. Stop blktrace."
sudo kill -INT $BPID

echo "Check blktrace_summary.log for the result."
blkparse -i blktrace_out -o /dev/null -d blktrace.bin
btt -i blktrace.bin > blktrace_summary.log
