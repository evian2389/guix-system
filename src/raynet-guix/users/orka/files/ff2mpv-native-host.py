#!/usr/bin/env python3
"""Minimal ff2mpv native messaging host."""

import json
import os
import struct
import subprocess
import sys


def read_message():
    header = sys.stdin.buffer.read(4)
    if len(header) != 4:
        return None
    size = struct.unpack("=I", header)[0]
    payload = sys.stdin.buffer.read(size)
    if len(payload) != size:
        return None
    return json.loads(payload.decode("utf-8"))


def send_message(value):
    payload = json.dumps(value, separators=(",", ":")).encode("utf-8")
    sys.stdout.buffer.write(struct.pack("=I", len(payload)))
    sys.stdout.buffer.write(payload)
    sys.stdout.buffer.flush()


def main():
    message = read_message()
    if not message:
        return
    url = message.get("url")
    if not isinstance(url, str) or not url.startswith(("http://", "https://")):
        send_message("Invalid or missing URL")
        return
    env = os.environ.copy()
    env["PATH"] = ":".join(filter(None, [
        "/home/orka/.guix-home/profile/bin",
        "/home/orka/.guix-profile/bin",
        "/run/current-system/profile/bin",
        env.get("PATH", ""),
    ]))
    subprocess.Popen(["mpv", "--no-terminal", "--", url], env=env)
    send_message("ok")


if __name__ == "__main__":
    main()
