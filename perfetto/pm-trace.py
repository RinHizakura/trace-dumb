#!/usr/bin/env python

import subprocess
import os
import re
from datetime import datetime

def set_wakealarm(rtcpath, rtcwaketime):
    os.system('echo 0 > '+ rtcpath +'/wakealarm')
    os.system('echo +%d > %s/wakealarm' % (rtcwaketime, rtcpath))


if os.geteuid() != 0:
    exit("Please run this script as root")

# Perfetto related path
basedir = os.path.dirname(os.path.realpath(__file__))
trace_box = "~/perfetto/out/linux/tracebox"
trace_cfg = os.path.join(basedir, "pm-trace.cfg")

# RTC clock related parameters
rtcpath="/sys/class/rtc/rtc1"
rtcwaketime=20

# Set RTC clock as wake source. Please awit that the perfetto
# tracer will stop after a specific time of suspend_start signal,
# so the time to tick RTC clock and complete resume progress should
# not longer than that.
set_wakealarm(rtcpath, rtcwaketime)

# Force tracing sysfs permission for user
os.system("sudo chown -R $USER /sys/kernel/tracing")
# Run perfetto as seperate routine
p = subprocess.Popen("%s -o trace_file.perfetto-trace --txt -c %s &" %
        (trace_box, trace_cfg), shell=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE)

(out, err) = p.communicate()

# Check "/sys/power/mem_sleep" for which type of sleep is selected.
os.system("echo mem > /sys/power/state")

# Wait until trace is done
p_status = p.wait()
