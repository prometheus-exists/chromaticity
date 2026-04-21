from __future__ import annotations

import argparse
import json
import sys

from .audio import list_input_devices
from .live import run_live
from .probe import probe_shader


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Chromaticity CLI")
    subparsers = parser.add_subparsers(dest="command", required=True)

    probe_parser = subparsers.add_parser("probe", help="Run the Phase 1 render-probe")
    probe_parser.add_argument("shader", help="Path to GLSL shader file")
    probe_parser.add_argument("output", help="Output profile path")
    probe_parser.add_argument("--itime-start", type=float, default=0.0)
    probe_parser.add_argument("--itime-end", type=float, default=60.0)
    probe_parser.add_argument("--itime-step", type=float, default=1.0)
    probe_parser.add_argument("--width", type=int, default=512)
    probe_parser.add_argument("--height", type=int, default=512)

    live_parser = subparsers.add_parser("live", help="Run the live audio-reactive runtime")
    live_parser.add_argument("shader", help="Path to GLSL shader file")
    live_parser.add_argument("--mapping", help="Optional mapping JSON path")
    live_parser.add_argument("--device", type=int, help="Audio input device index")
    live_parser.add_argument("--width", type=int, default=1280)
    live_parser.add_argument("--height", type=int, default=720)
    live_parser.add_argument("--fps", type=int, default=60)
    live_parser.add_argument("--fullscreen", action="store_true")

    subparsers.add_parser("devices", help="List audio input devices")

    args = parser.parse_args(argv)
    if args.command == "probe":
        probe_shader(
            shader_path=args.shader,
            output_path=args.output,
            itime_start=args.itime_start,
            itime_end=args.itime_end,
            itime_step=args.itime_step,
            resolution=(args.width, args.height),
        )
        return 0

    if args.command == "devices":
        devices = list_input_devices()
        print(json.dumps(devices, indent=2))
        return 0

    if args.command == "live":
        run_live(
            shader_path=args.shader,
            mapping_path=args.mapping,
            audio_device=args.device,
            width=args.width,
            height=args.height,
            fps=args.fps,
            fullscreen=args.fullscreen,
        )
        return 0

    parser.print_help(sys.stderr)
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
