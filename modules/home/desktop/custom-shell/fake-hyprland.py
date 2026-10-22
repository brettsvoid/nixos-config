"""A stand-in for Hyprland's two IPC sockets, for qs-test.

fake-hyprland.py <socket folder> <events file> <monitors file>

Answers every request on .socket.sock with empty JSON ({} for j/status, [] for the
rest; j/monitors with the monitors file, `hyprctl monitors -j`'s shape, while it exists)
and prints it (qs-test keeps the output in hyprland.log), and passes each line
appended to the events file (for example `configreloaded>>`) to every client of
.socket2.sock.
"""

import os
import socket
import sys
import threading
import time

folder, events_path, monitors_path = sys.argv[1], sys.argv[2], sys.argv[3]
os.makedirs(folder, exist_ok=True)
clients = []
lock = threading.Lock()


def listen(name):
    server = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    server.bind(os.path.join(folder, name))
    server.listen()
    return server


def answer_requests():
    server = listen(".socket.sock")
    while True:
        conn, _ = server.accept()
        request = conn.recv(65536).decode(errors="replace")
        print(request, flush=True)
        if request.endswith("monitors") and os.path.exists(monitors_path):
            with open(monitors_path, "rb") as monitors:
                conn.sendall(monitors.read())
        else:
            conn.sendall(b"{}" if request.endswith("status") else b"[]")
        conn.close()


def accept_event_clients():
    server = listen(".socket2.sock")
    while True:
        conn, _ = server.accept()
        with lock:
            clients.append(conn)


def pass_on_events():
    with open(events_path, "rb") as events:
        while True:
            line = events.readline()
            if not line:
                time.sleep(0.05)
                continue
            with lock:
                for conn in list(clients):
                    try:
                        conn.sendall(line if line.endswith(b"\n") else line + b"\n")
                    except OSError:
                        clients.remove(conn)


threading.Thread(target=answer_requests, daemon=True).start()
threading.Thread(target=accept_event_clients, daemon=True).start()
pass_on_events()
