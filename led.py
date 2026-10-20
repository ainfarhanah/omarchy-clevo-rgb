#!/usr/bin/env python3
"""Unprivileged, fixed-device LED control; JSON output for the panel."""
import json
import os
from pathlib import Path
import sys

DEVICE = Path('/sys/class/leds/rgb:kbd_backlight')

def numbers(path):
    return [int(v) for v in path.read_text().split()]

def state(device=DEVICE):
    order = (device / 'multi_index').read_text().split()
    if len(order) != 3 or set(order) != {'red', 'green', 'blue'}:
        raise ValueError('Unsupported LED channel layout')
    maximum = numbers(device / 'max_brightness')
    # This driver exposes per-channel maxima; do not guess for other drivers.
    limits = numbers(device / 'multi_max_intensity')
    values = numbers(device / 'multi_intensity')
    brightness = numbers(device / 'brightness')
    if len(maximum) != 1 or maximum[0] <= 0 or len(brightness) != 1:
        raise ValueError('Invalid brightness attributes')
    if len(limits) != 3 or len(values) != 3 or any(v <= 0 for v in limits):
        raise ValueError('Invalid RGB attributes')
    if not 0 <= brightness[0] <= maximum[0] or any(not 0 <= v <= m for v, m in zip(values, limits)):
        raise ValueError('LED values outside reported limits')
    return dict(ok=True, brightness=brightness[0], maximum=maximum[0],
                order=order, rgb=dict(zip(order, values)), limits=dict(zip(order, limits)),
                writable=all(os.access(device / f, os.W_OK) for f in ('brightness', 'multi_intensity')))

def apply(args, device=DEVICE):
    current = state(device)
    if len(args) != 4 or any(not v.isascii() or not v.isdecimal() for v in args):
        raise ValueError('Expected brightness, red, green, blue as nonnegative integers')
    brightness, red, green, blue = map(int, args)
    rgb = dict(red=red, green=green, blue=blue)
    if brightness > current['maximum'] or any(rgb[k] > current['limits'][k] for k in rgb):
        raise ValueError('Requested value exceeds device limits')
    # Open both before changing either: a missing permission must not partially apply.
    # Kernel writes are not transactional; report any subsequent failure to the UI.
    with (device / 'multi_intensity').open('r+') as color_file, (device / 'brightness').open('r+') as brightness_file:
        color_file.write(' '.join(str(rgb[k]) for k in current['order']) + '\n')
        color_file.flush()
        brightness_file.write(str(brightness) + '\n')
        brightness_file.flush()
    return state(device)

def main():
    try:
        if sys.argv[1:] == ['state']:
            result = state()
        elif sys.argv[1:2] == ['set']:
            result = apply(sys.argv[2:])
        else:
            raise ValueError('Usage: led.py state | set BRIGHTNESS RED GREEN BLUE')
        print(json.dumps(result))
        return 0
    except (OSError, ValueError) as error:
        print(json.dumps(dict(ok=False, error=str(error))))
        return 1

if __name__ == '__main__':
    sys.exit(main())
