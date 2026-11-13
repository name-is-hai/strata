#!/usr/bin/env python3
"""Exercise real TCP connections and child cleanup without touching the desktop."""
import pathlib
import ast
import select
import signal
import socket
import subprocess
import sys
import tempfile
import time


def wait_for(condition):
    deadline = time.monotonic() + 8
    while time.monotonic() < deadline:
        if condition():
            return
        time.sleep(0.02)
    raise AssertionError('Timed out waiting for connection cleanup')


with tempfile.TemporaryDirectory(prefix='strata-rdp-listener-') as directory:
    root = pathlib.Path(directory)
    marker = root / 'virtual-monitor'
    backend = root / 'backend.py'
    backend.write_text('''import pathlib, signal, socket, sys
marker = pathlib.Path(sys.argv[1])
def stop(*_):
    marker.unlink(missing_ok=True)
    sys.exit(0)
signal.signal(signal.SIGTERM, stop)
marker.touch()
host, port = sys.argv[2].split(':')
with socket.create_server((host, int(port))) as listener:
    while True:
        connection, _ = listener.accept()
        with connection:
            while data := connection.recv(65536):
                connection.sendall(data)
''')
    helper = pathlib.Path(__file__).resolve().parents[2] / 'bin/strata-remote-desktop-listener'
    # Bind port zero in the actual listener, avoiding fixed test ports.
    launch = ('import runpy,sys; module=runpy.run_path(sys.argv[1]); '
              'module["listen"](sys.argv[2:], ("127.0.0.1", 0))')
    process = subprocess.Popen([sys.executable, '-c', launch, str(helper),
                                sys.executable, str(backend), str(marker)],
                               stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    try:
        assert select.select([process.stdout], [], [], 5)[0], 'listener ready'
        line = process.stdout.readline()
        assert line.startswith('RDP listener ready'), line or process.stderr.read()
        address = ast.literal_eval(line.split(' on ', 1)[1].split(';', 1)[0])
        assert not marker.exists(), 'idle listener creates no virtual monitor'
        for attempt in range(2):
            with socket.create_connection(address, timeout=5) as client:
                client.sendall(b'encrypted RDP test bytes\x00\xff')
                assert client.recv(1024) == b'encrypted RDP test bytes\x00\xff', 'bytes forwarded unchanged'
                assert marker.exists(), 'backend starts on demand'
                with socket.create_connection(address, timeout=5) as second:
                    assert second.recv(1) == b'', 'concurrent clients cannot race restoration'
            wait_for(lambda: not marker.exists())
        client = socket.create_connection(address, timeout=5)
        client.sendall(b'active shutdown')
        assert client.recv(1024) == b'active shutdown'
        process.send_signal(signal.SIGTERM)
        process.wait(timeout=8)
        client.close()
        assert not marker.exists(), 'stopping the listener drains backend cleanup'
        assert process.returncode == 0, process.stderr.read()
    finally:
        if process.poll() is None:
            process.terminate()
            process.wait(timeout=30)
    print('PASS: idle without a monitor, transparent TCP forwarding, disconnect cleanup, reconnect and active stop')
