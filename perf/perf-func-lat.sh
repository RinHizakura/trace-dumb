#!/usr/bin/env bash
# Measure function entry-to-return latency using perf probe.
# Usage: sudo perf-func-lat.sh -f <function> [cmd args...]
# Example: sudo perf-func-lat.sh -f arm_smmu_iotlb_sync fio --filename=... --runtime=3

PERF=perf

if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root."
    exit 1
fi

FUNC=
while getopts ":f:" opt; do
    case $opt in
        f) FUNC=$OPTARG ;;
        ?) echo "Usage: $0 -f <function> [cmd...]"; exit 1 ;;
    esac
done
shift $(($OPTIND - 1))
CMD=$*

if [[ -z $FUNC || -z $CMD ]]; then
    echo "Usage: $0 -f <function> [cmd...]"
    exit 1
fi

TMPFILE=$(mktemp /tmp/perf_lat.XXXXXX)
trap "rm -f $TMPFILE ${TMPFILE}.data; $PERF probe --del 'probe:${FUNC}*' 2>/dev/null" EXIT

$PERF probe --del "probe:${FUNC}*" 2>/dev/null
$PERF probe --add "$FUNC" || exit 1
$PERF probe --add "${FUNC}%return" || exit 1

$PERF record -c 1 -e "probe:${FUNC},probe:${FUNC}__return" -aR -o "${TMPFILE}.data" $CMD

$PERF script -i "${TMPFILE}.data" -F "comm,pid,tid,cpu,time,event" 2>/dev/null > "$TMPFILE"

awk '
/probe:/ {
    ptid = $2
    t = $4; sub(/:$/, "", t)
    event = $5; sub(/:$/, "", event)

    if (index(event, "__return") > 0) {
        if (ptid in entry) {
            delta = (t - entry[ptid]) * 1e6
            if (delta > 0) {
                n++; sum += delta
                if (n == 1 || delta < min) min = delta
                if (delta > max) max = delta
                b = int(delta); if (b > 9999) b = 9999
                hist[b]++
            }
            delete entry[ptid]
        }
    } else {
        entry[ptid] = t
    }
}
END {
    if (n == 0) { print "No data collected."; exit 1 }
    printf "\n=== %s latency ===\n", func
    printf "count=%-7d  avg=%7.2f us  min=%6.2f us  max=%8.2f us\n", n, sum/n, min, max
    cum = 0
    for (b = 0; b <= 9999; b++) {
        if (!(b in hist)) continue
        cum += hist[b]
        pct = cum * 100 / n
        if (!p50  && pct >= 50)  p50  = b
        if (!p95  && pct >= 95)  p95  = b
        if (!p99  && pct >= 99)  p99  = b
        if (!p999 && pct >= 99.9) p999 = b
    }
    printf "p50=~%d us  p95=~%d us  p99=~%d us  p99.9=~%d us\n", p50, p95, p99, p999
}
' func="$FUNC" "$TMPFILE"
