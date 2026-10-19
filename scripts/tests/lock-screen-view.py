#!/usr/bin/env python3
"""Exercise shared login/lock UI without PAM, greetd, or real power actions."""
import os
from pathlib import Path
import subprocess
import tempfile

repo = Path(__file__).resolve().parents[2]
fixture = Path(__file__).with_suffix('.qml')
with tempfile.TemporaryDirectory(prefix='strata-lock-view-') as directory:
    work = Path(directory)
    (work / 'Commons').symlink_to(repo / 'shell/Commons', target_is_directory=True)
    (work / 'Ui').symlink_to(repo / 'shell/Ui', target_is_directory=True)
    (work / 'shell.qml').write_bytes(fixture.read_bytes())
    runtime = work / 'runtime'
    runtime.mkdir(mode=0o700)
    env = os.environ.copy()
    for name in ('WAYLAND_DISPLAY', 'HYPRLAND_INSTANCE_SIGNATURE', 'GREETD_SOCK'):
        env.pop(name, None)
    env.update(QT_QPA_PLATFORM='offscreen', QT_QUICK_BACKEND='software',
               XDG_RUNTIME_DIR=str(runtime), STRATA_TEST_REPO=str(repo),
               STRATA_TEST_OUTPUT=str(work))
    result = subprocess.run(['quickshell', '-n', '-p', str(work / 'shell.qml')],
                            env=env, capture_output=True, text=True, timeout=15)
    output = result.stdout + result.stderr
    if result.returncode or 'FAIL:' in output or 'PASS: shared full-screen views rendered' not in output:
        raise SystemExit(output)
    if (work / 'lock.png').read_bytes() != (work / 'greeter.png').read_bytes():
        raise SystemExit('FAIL: login and lock views rendered different pixels')
    print('PASS: shared login/lock UI interactions and identical full-screen rendering')
