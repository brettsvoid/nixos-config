#!/usr/bin/env python3

import json
import os
import sys
import urllib.parse
import urllib.request
from datetime import datetime, timedelta

API_URL = "http://localhost:3002"
API_KEY = os.getenv("TYTO_API_KEY")

task_hash = ""


def main(argv):
    data = get_data()
    if data["start_time"]:
        time_info = calculate_progress(data["start_time"], data["task"])
        render(data["label"], time_info)
        print(data["label"], time_info)
    else:
        # os.system(f"sketchybar --remove tyto_task")
        render("", {"is_overtime": False, "time_left": "", "time_over": ""})
        print("doing nothing")

    return 0


def render(label, time_info):
    if time_info["is_overtime"]:
        os.system(
            f'sketchybar --set tyto_task label="{label}: Overtime by {time_info["time_over"]}" label.color=0xffcad3f5'
        )
    else:
        os.system(
            f'sketchybar --set tyto_task label="{label}: {time_info["time_left"]} left" label.color=0xffcad3f5'
        )


def calculate_progress(start_time, task):
    result = {"is_overtime": False, "time_left": "", "time_over": ""}
    dt = datetime.fromisoformat(start_time)
    hours_alloc = task["hoursAllocated"]
    hours_taken = task["hoursTaken"]

    deadline = dt + timedelta(hours=hours_alloc) - timedelta(hours=hours_taken)
    now = datetime.now(deadline.tzinfo) if deadline.tzinfo else datetime.now()
    delta = deadline - now
    if delta.total_seconds() >= 0:
        h, rem = divmod(delta.total_seconds(), 3600)
        m = rem // 60
        result["time_left"] = f"{int(h)}h {int(m)}m"
        print(f"Time left until {deadline.isoformat()}: {int(h)}h {int(m)}m")
    else:
        # past deadline
        over = -delta
        h, rem = divmod(over.total_seconds(), 3600)
        m = rem // 60
        result["is_overtime"] = True
        result["time_over"] = f"{int(h)}h {int(m)}m"
        print(f"Deadline missed by: {int(h)}h {int(m)}m")

    return result


def get_data():
    result = {"label": "", "start_time": None, "task": None}

    # get current state of current task
    user = get_user()
    result["start_time"] = user["currentTaskStartDate"]
    task_id = user["currentTaskId"]
    if task_id:
        task = get_task(task_id)
        result["label"] = task["title"]
        result["task"] = task

    # display current task title
    return result


def get_user():
    resp, data = fetch(f"{API_URL}/v1/users/me")
    if resp.status != 200:
        print(resp.status, data)
        raise Exception("get_user request failed")

    return data


def get_task(task_id):
    resp, data = fetch(
        f"{API_URL}/v1/tasks/{task_id}?{urllib.parse.urlencode({"h": task_hash})}"
    )
    if resp.status != 200:
        print(resp.status, data)
        raise Exception("get_task request failed")

    return data


def fetch(url):
    req = urllib.request.Request(
        url,
        headers={
            "User-Agent": "Python-BrettMacMini/1.0",
            "Accept": "application/json",
            "Content-Type": "application/json",
            "Authorization": f"Bearer {API_KEY}",
        },
    )
    with urllib.request.urlopen(req) as resp:
        body = resp.read()
        data = json.loads(body)
        return resp, data


if __name__ == "__main__":
    main(sys.argv)
