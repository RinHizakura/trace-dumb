#!/usr/bin/env bash

PERF=perf
OUTPUT=/tmp/perf_result

if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root user."
    exit 1
fi

FUNC=
while getopts ":f:" opt
do
    case $opt in
        f)
            FUNC=$OPTARG;;
        ?)
            exit 1;;
    esac
done

shift $(($OPTIND - 1))
CMD=$*

if [[ -z $FUNC ]]; then
    echo "Please specific the trace function by -f option"
    exit 1
fi

# Remove all old probes
perf probe --del "probe:*"

perf probe --add $FUNC
perf probe --add "${FUNC}%return"
perf record -e probe:${FUNC}* $CMD
# Output result
perf script -F "comm,pid,tid,cpu,time,event" > $OUTPUT
echo "Done. Please 'sudo cat $OUTPUT' for the result"

perf probe --del=probe:${FUNC}
perf probe --del=probe:${FUNC}__return
