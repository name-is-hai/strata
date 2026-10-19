#!/usr/bin/env python3
"""Observe PipeWire graph metadata and device handles; never read media."""
import codecs
import json
import os
from pathlib import Path
import re
import selectors
import signal
import subprocess
import sys
import time


def props(obj):
    return (obj.get('info') or {}).get('props') or {}


def muted(obj):
    return any(row.get('mute') is True for row in
               ((obj.get('info') or {}).get('params') or {}).get('Props', []))


def label(obj):
    p = props(obj)
    return str(p.get('application.name') or p.get('application.process.binary')
               or p.get('node.description') or p.get('media.name') or 'Unknown app')[:160]


def screen_source(obj):
    p = props(obj)
    return p.get('media.role') == 'Screen' or str(p.get('media.name', '')).startswith('xdph-streaming-')


def merge_objects(objects, changes):
    for obj in changes:
        if not isinstance(obj, dict) or 'id' not in obj:
            continue
        ident = obj['id']
        if 'info' in obj and obj['info'] is None:
            objects.pop(ident, None)
            continue
        previous = objects.setdefault(ident, {})
        for key, value in obj.items():
            if key == 'info' and isinstance(value, dict):
                info = previous.setdefault('info', {})
                for field, data in value.items():
                    if field in ('props', 'params') and isinstance(data, dict):
                        info.setdefault(field, {}).update(data)
                    else:
                        info[field] = data
            else:
                previous[key] = value


def classify(objects, direct=None, ready=True):
    nodes = {key: value for key, value in objects.items()
             if value.get('type') == 'PipeWire:Interface:Node'}
    upstream = {}
    for value in objects.values():
        if value.get('type') != 'PipeWire:Interface:Link':
            continue
        info = value.get('info') or {}
        if info.get('state') not in ('active', 'paused'):
            continue
        out = info.get('output-node-id', props(value).get('link.output.node'))
        inp = info.get('input-node-id', props(value).get('link.input.node'))
        upstream.setdefault(inp, []).append(out)

    def sources(ident, visited=None):
        visited = set() if visited is None else visited
        if ident in visited:
            return []
        visited.add(ident)
        result = []
        for parent in upstream.get(ident, []):
            node = nodes.get(parent)
            if not node:
                continue
            result.append(node)
            result.extend(sources(parent, visited))
        return result

    activity = {'camera': [], 'microphone': [], 'screen': []}
    camera_sources = []
    for ident, node in nodes.items():
        p = props(node)
        media_class = p.get('media.class', '')
        state = (node.get('info') or {}).get('state')
        if media_class == 'Video/Source' and not screen_source(node) and state == 'running':
            camera_sources.append({'app': label(node), 'muted': False})
        if media_class == 'Video/Source' and screen_source(node):
            # An exported portal session remains sensitive even when temporarily idle.
            activity['screen'].append({'app': label(node), 'muted': False})
        if media_class not in ('Stream/Input/Audio', 'Stream/Input/Video') or state != 'running':
            continue
        parents = sources(ident)
        if media_class == 'Stream/Input/Audio':
            microphones = [n for n in parents if props(n).get('media.class') == 'Audio/Source'
                           and not str(props(n).get('node.name', '')).endswith('.monitor')
                           and props(n).get('stream.capture.sink') is not True]
            # A desktop-audio monitor comes from Audio/Sink, not a microphone.
            if microphones:
                activity['microphone'].append({'app': label(node),
                    'muted': muted(node) or all(muted(n) for n in microphones)})
        else:
            screens = [n for n in parents if screen_source(n)]
            cameras = [n for n in parents if props(n).get('media.class') == 'Video/Source'
                       and not screen_source(n)]
            if screens or screen_source(node):
                activity['screen'].append({'app': label(node), 'muted': False})
            elif cameras or p.get('media.role') == 'Camera':
                activity['camera'].append({'app': label(node), 'muted': False})
    for kind, rows in (direct or {}).items():
        activity[kind].extend(rows)
    if not activity['camera']:
        activity['camera'].extend(camera_sources)
    for kind, rows in activity.items():
        unique = {}
        for row in rows:
            key = row['app']
            if key not in unique:
                unique[key] = dict(row)
            else:
                unique[key]['muted'] = unique[key]['muted'] and row['muted']
        activity[kind] = sorted(unique.values(), key=lambda row: row['app'].lower())
    activity['recording'] = any(row['app'] in ('gpu-screen-reco', 'gpu-screen-recorder', 'wf-recorder') for row in (direct or {}).get('screen', []))
    activity['ready'] = ready
    return activity


def direct_activity(proc=Path('/proc'), uid=None, camera_present=None):
    uid = os.getuid() if uid is None else uid
    camera_present = any(Path('/sys/class/video4linux').glob('video*')) if camera_present is None else camera_present
    result = {'camera': [], 'microphone': [], 'screen': []}
    try:
        processes = list(proc.iterdir())
    except OSError:
        return result
    for process in processes:
        if not process.name.isdigit():
            continue
        try:
            if process.stat().st_uid != uid or int(process.name) == os.getpid():
                continue
            name = (process / 'comm').read_text().strip()
            if name in ('gpu-screen-reco', 'gpu-screen-recorder', 'wf-recorder'):
                result['screen'].append({'app': name, 'muted': False})
            if name in ('pipewire', 'wireplumber', 'pw-dump'):
                continue
            for fd in (process / 'fd').iterdir():
                try:
                    target = os.readlink(fd)
                except OSError:
                    continue
                if camera_present and re.fullmatch(r'/dev/video\d+', target):
                    result['camera'].append({'app': name, 'muted': False})
                elif re.fullmatch(r'/dev/snd/pcmC\d+D\d+c', target):
                    result['microphone'].append({'app': name, 'muted': False})
        except (OSError, ValueError):
            continue
    return result


def watch():
    stopped = False
    def stop(*_):
        nonlocal stopped
        stopped = True
    signal.signal(signal.SIGTERM, stop)
    signal.signal(signal.SIGINT, stop)
    decoder = json.JSONDecoder()
    last = None
    while not stopped:
        objects, buffer, ready = {}, '', False
        child = None
        try:
            child = subprocess.Popen(['setpriv', '--pdeathsig', 'TERM', 'pw-dump', '--monitor'],
                stdout=subprocess.PIPE, stderr=subprocess.DEVNULL)
            utf8 = codecs.getincrementaldecoder('utf-8')(errors='replace')
            with selectors.DefaultSelector() as selector:
                selector.register(child.stdout, selectors.EVENT_READ)
                direct, scanned = {}, 0
                while not stopped and child.poll() is None:
                    for key, _ in selector.select(timeout=0.5):
                        raw = os.read(key.fileobj.fileno(), 65536)
                        if not raw:
                            break
                        buffer += utf8.decode(raw)
                        while buffer.strip():
                            buffer = buffer.lstrip()
                            try:
                                changes, end = decoder.raw_decode(buffer)
                            except json.JSONDecodeError:
                                break
                            buffer = buffer[end:]
                            if isinstance(changes, list):
                                merge_objects(objects, changes)
                                ready = True
                        if len(buffer) > 16 * 1024 * 1024:
                            raise ValueError('Invalid PipeWire event stream')
                    if time.monotonic() - scanned >= 2:
                        direct = direct_activity()
                        scanned = time.monotonic()
                    state = classify(objects, direct, ready)
                    encoded = json.dumps(state, separators=(',', ':'), sort_keys=True)
                    if encoded != last:
                        print(encoded, flush=True)
                        last = encoded
        except (OSError, ValueError):
            pass
        finally:
            if child:
                child.terminate()
                try:
                    child.wait(timeout=2)
                except subprocess.TimeoutExpired:
                    child.kill()
                    child.wait()
        if not stopped:
            state = classify({}, direct_activity(), False)
            encoded = json.dumps(state, separators=(',', ':'), sort_keys=True)
            if encoded != last:
                print(encoded, flush=True)
                last = encoded
            time.sleep(1)


if __name__ == '__main__':
    watch()
