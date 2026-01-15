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

function check_command()
{
    command -v $1 >/dev/null 2>&1 || { echo >&2 "This script requires $1 but it's not installed. Aborting."; exit 1; }
}
check_command blktrace
check_command blkparse
check_command btt

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
    echo "Please provide a command to run."
    print_help
    exit 1
fi

if [ -z $DEV ]; then
    echo "Please specific the block device for tracing"
    print_help
    exit 1
fi

if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root user."
    exit 1
fi

OUTPUT_DIR="blktrace_output"
rm -rf $OUTPUT_DIR/*
mkdir -p $OUTPUT_DIR

BLKTRACE_OUT="$OUTPUT_DIR/blktrace_out"
BLKTRACE_BIN="$OUTPUT_DIR/blktrace.bin"

BLKTRACE_CMD="blktrace -d $DEV -o $BLKTRACE_OUT"
echo "Starting running blktrace: $BLKTRACE_CMD"
echo "Running command: $CMD"
$BLKTRACE_CMD &
BPID=$!
$CMD
kill -INT $BPID
echo "Complete I/O operation. Stop blktrace."

BLKPARSE_CMD="blkparse -i $BLKTRACE_OUT -o - -d $BLKTRACE_BIN"
BTT_CMD="btt -i $BLKTRACE_BIN"
$BLKPARSE_CMD
$BTT_CMD > "$OUTPUT_DIR/btt_report.txt"
echo "Blktrace and BTT reports are saved in $OUTPUT_DIR"
