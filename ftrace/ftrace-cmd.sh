#!/usr/bin/env bash

CMD=$@
SYSFS_TRACE=/sys/kernel/debug/tracing

function root_run()
{
    sudo sh -c "$1"
}

cd $SYSFS_TRACE

# Disable the trace first before we setup everything
root_run "echo 0 > tracing_on"
root_run "echo 0 > trace"

# Choose the function tracer
root_run "echo function > current_tracer"

# Enable trace and start running the command
(sleep 5; $CMD) &
CPID=$!
echo "Run command '$CMD'(ppid=$$ pid=$CPID) and enable tracing..."

# Add child pid to filter to start tracing it
root_run "echo function-fork > trace_options"
root_run "echo $CPID > set_ftrace_pid"
root_run "echo 1 > tracing_on"
wait $CPID
root_run "echo 0 > tracing_on"

# Cleanup the change of ftrace-cmd
root_run "echo nop > current_tracer"
root_run "echo > set_ftrace_pid"
root_run "echo nofunction-fork > trace_options"
echo "Done. Please 'sudo cat $SYSFS_TRACE/trace' for the result"
