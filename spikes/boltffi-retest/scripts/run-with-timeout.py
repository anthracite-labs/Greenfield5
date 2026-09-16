#!/usr/bin/env python3
"""Run a command under a hard wall-clock ceiling.

macOS runners have no `timeout(1)`, and PR #17 learned that an unbounded
`xcodebuild test` can wedge a whole job. This kills the process group so no
simulator or build daemon survives the ceiling.
"""
import os
import signal
import subprocess
import sys
import time

if len(sys.argv) < 4:
    sys.stderr.write("usage: run-with-timeout.py SECONDS LOGFILE CMD [ARGS...]\n")
    raise SystemExit(2)

seconds = int(sys.argv[1])
log_path = sys.argv[2]
command = sys.argv[3:]

with open(log_path, "ab") as log:
    log.write(("---- %s ----\n" % " ".join(command)).encode())
    process = subprocess.Popen(
        command, stdout=log, stderr=subprocess.STDOUT, start_new_session=True
    )
    try:
        code = process.wait(timeout=seconds)
    except subprocess.TimeoutExpired:
        log.write(("\nTIMEOUT: exceeded %ss: %s\n" % (seconds, " ".join(command))).encode())
        log.flush()
        for sig in (signal.SIGTERM, signal.SIGKILL):
            try:
                os.killpg(process.pid, sig)
            except ProcessLookupError:
                break
            try:
                process.wait(timeout=10)
                break
            except subprocess.TimeoutExpired:
                continue
        code = 124

sys.exit(code)
