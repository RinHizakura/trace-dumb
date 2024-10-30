#!/usr/bin/env python3

import argparse, re
import pandas as pd
import numpy as np


def get_args():
    parser = argparse.ArgumentParser()
    parser.add_argument("input")
    args = parser.parse_args()
    return args


header = ["comm", "pid/tid", "cpu", "time", "event"]

args = get_args()
input_file = args.input

# Parse output file to know the function execution time by
# the entry and exit timestamp
data = []
entry_time = {}
with open(input_file, "r") as file:
    for line in file:
        l = line.strip()
        items = re.split(r"\s+", l)

        ptid = items[0] + items[1]
        func = re.search(r":\w+:", items[4])[0][1:-1]
        # Use us unit
        time = float(items[3][:-1]) * 10**6

        if len(func) >= 8 and func[-8:] == "__return":
            data.append(time - entry_time[ptid])
            entry_time.pop(ptid)
        else:
            assert entry_time.get(ptid) == None
            entry_time[ptid] = time

data = np.array(data)

# Show stat on the target CPU
print(f"Totol data={len(data)}us, total time={np.sum(data)}us")
print(f"min={np.min(data)}us, mean={np.mean(data)}us, max={np.max(data)}us")
