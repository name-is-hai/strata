#!/usr/bin/env python3
"""Private compositor IPC fixture; no real pointer movement or cursor changes."""
import os
from pathlib import Path
import signal
import socket
import subprocess
import sys
import tempfile
import threading
import time
import unittest

BINARY = os.path.abspath(sys.argv.pop(1))

class Lifecycle(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="strata-wiggle-ipc-")
        self.root = Path(self.temp.name)
        (self.root / 'hypr' / 'fixture').mkdir(parents=True)
        self.socket = socket.socket(socket.AF_UNIX)
        self.socket.bind(str(self.root / 'hypr' / 'fixture' / '.socket.sock'))
        self.socket.listen()
        self.socket.settimeout(.1)
        self.requests = []
        self.reply = b'ok'
        self.done = threading.Event()
        self.thread = threading.Thread(target=self.serve)
        self.thread.start()
        self.env = dict(os.environ, XDG_RUNTIME_DIR=str(self.root), HYPRLAND_INSTANCE_SIGNATURE='fixture')

    def serve(self):
        while not self.done.is_set():
            try:
                conn, _ = self.socket.accept()
            except socket.timeout:
                continue
            with conn:
                self.requests.append(conn.recv(4096).decode())
                try: conn.sendall(self.reply)
                except BrokenPipeError: pass

    def tearDown(self):
        self.done.set()
        self.thread.join(timeout=2)
        self.socket.close()
        self.temp.cleanup()

    def test_restore_requires_acknowledgement(self):
        self.assertEqual(subprocess.run([BINARY, '--restore'], env=self.env).returncode, 0)
        self.assertIn('invisible = false', self.requests[-1])
        self.reply = b'error'
        self.assertNotEqual(subprocess.run([BINARY, '--restore'], env=self.env).returncode, 0)

    def test_stdin_closure_restores_native_cursor(self):
        child = subprocess.Popen([BINARY], env=self.env, stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True)
        try:
            child.stdin.write('HIDE\n'); child.stdin.flush()
            self.assertEqual(child.stdout.readline().strip(), 'HIDDEN')
            child.stdin.close()
            self.assertEqual(child.wait(timeout=3), 0)
            self.assertIn('invisible = false', self.requests[-1])
        finally:
            if child.poll() is None: child.kill(); child.wait()
            child.stdout.close()

    def test_parent_sigkill_restores_native_cursor(self):
        code = '''import subprocess,sys,time
child=subprocess.Popen([sys.argv[1]],stdin=subprocess.PIPE,stdout=subprocess.PIPE,stderr=subprocess.DEVNULL,text=True)
child.stdin.write("HIDE\\n");child.stdin.flush()
assert child.stdout.readline().strip()=="HIDDEN"
print("READY",flush=True)
time.sleep(30)
'''
        parent = subprocess.Popen([sys.executable, '-c', code, BINARY], env=self.env, stdout=subprocess.PIPE, text=True)
        try:
            self.assertEqual(parent.stdout.readline().strip(), 'READY')
            hidden_at = len(self.requests)
            parent.kill(); parent.wait(timeout=3)
            for _ in range(100):
                if len(self.requests) > hidden_at and 'invisible = false' in self.requests[-1]: break
                time.sleep(.02)
            self.assertGreater(len(self.requests), hidden_at)
            self.assertIn('invisible = false', self.requests[-1])
        finally:
            if parent.poll() is None: parent.kill(); parent.wait()
            parent.stdout.close()

if __name__ == '__main__': unittest.main()
