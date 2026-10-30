"""Build app/public/assets/models/clips.json from rigged GLBs + Three.js clip JSON.

Every Higgsfield/Meshy auto-rig shares bone names, so clips extracted here play
on both Khione and Oreo. Usage:

  python3 tools/extract_clips.py out.json key=source[:clipIndex] ...

A source is either a .glb (its animations are read) or a .json list of
Three.js AnimationClip objects (picked by name, e.g. poc_clips.json#run).
"""
import json
import struct
import sys

COMP = {5126: ('f', 4), 5123: ('H', 2), 5121: ('B', 1), 5122: ('h', 2), 5120: ('b', 1)}
NCOMP = {'SCALAR': 1, 'VEC3': 3, 'VEC4': 4}
NORM = {5123: 65535.0, 5121: 255.0, 5122: 32767.0, 5120: 127.0}


def read_glb(path):
    d = open(path, 'rb').read()
    jlen = struct.unpack('<I', d[12:16])[0]
    j = json.loads(d[20:20 + jlen])
    off = 20 + jlen
    blen = struct.unpack('<I', d[off:off + 4])[0]
    binc = d[off + 8:off + 8 + blen]
    return j, binc


def accessor(j, binc, i):
    a = j['accessors'][i]
    bv = j['bufferViews'][a['bufferView']]
    fmt, size = COMP[a['componentType']]
    n = NCOMP[a['type']]
    stride = bv.get('byteStride', size * n)
    base = bv.get('byteOffset', 0) + a.get('byteOffset', 0)
    out = []
    for k in range(a['count']):
        o = base + k * stride
        vals = struct.unpack('<' + fmt * n, binc[o:o + size * n])
        if a['componentType'] != 5126 and a.get('normalized'):
            vals = [max(v / NORM[a['componentType']], -1.0) for v in vals]
        out.extend(vals)
    return out


def glb_clips(path):
    j, binc = read_glb(path)
    clips = []
    for an in j.get('animations', []):
        tracks = []
        dur = 0
        for ch in an['channels']:
            node = j['nodes'][ch['target']['node']].get('name', 'node')
            p = ch['target']['path']
            s = an['samplers'][ch['sampler']]
            times = accessor(j, binc, s['input'])
            vals = accessor(j, binc, s['output'])
            dur = max(dur, times[-1] if times else 0)
            typ = {'rotation': 'quaternion', 'translation': 'vector', 'scale': 'vector'}[p]
            prop = {'rotation': 'quaternion', 'translation': 'position', 'scale': 'scale'}[p]
            tracks.append({'name': f'{node}.{prop}', 'times': [round(t, 4) for t in times],
                           'values': [round(v, 5) for v in vals], 'type': typ})
        clips.append({'name': an.get('name', 'clip'), 'duration': round(dur, 4), 'tracks': tracks, 'blendMode': 2500})
    return clips


def trim_track(t, a, b):
    n = len(t['values']) // max(1, len(t['times']))
    keep = [i for i, tm in enumerate(t['times']) if a - 1e-4 <= tm <= b + 1e-4]
    if not keep:
        keep = [0]
    return {**t, 'times': [round(t['times'][i] - a, 4) for i in keep],
            'values': [v for i in keep for v in t['values'][i * n:(i + 1) * n]]}


def hips_y(clip):
    for t in clip['tracks']:
        if t['name'].lower().startswith('hips.') and t['name'].endswith('.position'):
            return t['values'][1]
    return None


def main():
    out = sys.argv[1]
    result = {'clips': {}}
    for arg in sys.argv[2:]:
        key, src = arg.split('=', 1)
        trim = None
        if '@' in src:
            src, rng_ = src.split('@', 1)
            trim = tuple(float(x) for x in rng_.split('-'))
        if '#' in src:
            path, name = src.split('#', 1)
            pool = json.load(open(path))
            clip = next(c for c in pool if c['name'] == name)
        else:
            path, _, idx = src.partition(':')
            clip = glb_clips(path)[int(idx or 0)]
        clip = dict(clip)
        clip['name'] = key
        clip['hipsY'] = hips_y(clip)
        # Keep rotations + hip translation only: scale and other bone offsets
        # fight per-character proportions (the runtime drops them too).
        clip['tracks'] = [t for t in clip['tracks'] if t['name'].endswith('.quaternion')
                          or (t['name'].lower().startswith('hips.') and t['name'].endswith('.position'))]
        if trim:
            clip['tracks'] = [trim_track(t, *trim) for t in clip['tracks']]
            clip['duration'] = round(trim[1] - trim[0], 4)
        for t in clip['tracks']:
            t['values'] = [round(v, 4) for v in t['values']]
        result['clips'][key] = clip
        print(f"{key:8s} {clip['duration']:5.2f}s tracks={len(clip['tracks'])} hipsY={clip['hipsY']}")
    json.dump(result, open(out, 'w'), separators=(',', ':'))


if __name__ == '__main__':
    main()
