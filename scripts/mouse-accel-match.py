#!/usr/bin/env python3
"""Match YeetMouse (Linux) and RawAccel (Windows) mouse-acceleration curves.

Both tools implement the *same* Jump-mode math; the parameters map 1:1 but the
controls are named differently and RawAccel clamps smoothing differently. This
tool makes that mapping explicit, simulates the sensitivity curve faithfully
from the upstream source, DPI-compensates when the two machines run different
DPI, and quantifies how far apart two concrete configs actually are.

Formulas transcribed verbatim from upstream source (not approximated):
  - RawAccel:  common/accel-jump.hpp   (RawAccelOfficial/rawaccel)
  - YeetMouse: driver/accel_modes.c    (AndyFilter/YeetMouse)

Both define, for input |speed| in mouse counts per millisecond, a sensitivity
*ratio* f(speed) applied to the raw delta, then scaled by the base sensitivity:

    rate r = 2*pi / (smooth * midpoint)
        (RawAccel additionally forces r = 0 -- a hard step -- when
         smooth*midpoint < 1; YeetMouse uses any smooth > 0 directly.)

    Legacy / "sensitivity" variant   (RawAccel Gain OFF  ==  YeetMouse UseSmoothing OFF):
        r != 0 :  f = 1 + (accel-1) / (1 + exp(r*(midpoint - speed)))
        r == 0 :  f = 1               for speed <  midpoint
                  f = accel           for speed >= midpoint

    Gain variant                     (RawAccel Gain ON   ==  YeetMouse UseSmoothing ON):
        antideriv(x) = (accel-1) * (x + softplus(r*(midpoint-x)) / r)
        f(x) = 1 + (antideriv(x) - antideriv(0)) / x

    applied sensitivity = base_sensitivity * f(speed)

No third-party dependencies; pure stdlib.
"""

from __future__ import annotations

import argparse
import math
from dataclasses import dataclass, replace

# Field names: the SAME physical quantity, named per tool.
#   midpoint     <- YeetMouse "Midpoint"        / RawAccel "Input"
#   accel        <- YeetMouse "Acceleration"    / RawAccel "Output"
#   smooth       <- YeetMouse "Smoothness"      / RawAccel "Smooth"
#   sensitivity  <- YeetMouse "Sensitivity X"   / RawAccel "Sens Multiplier"
#   gain         <- YeetMouse "Use Smoothing"   / RawAccel "Gain"  (True == gain variant)
#   dpi          <- mouse DPI on that machine (counts per inch)


@dataclass(frozen=True)
class JumpConfig:
    midpoint: float = 7.8
    accel: float = 2.0
    smooth: float = 0.0
    sensitivity: float = 0.5
    gain: bool = False
    dpi: int = 800


_SOFTPLUS_THRESHOLD = 30.0  # mirrors YeetMouse EXP_ARG_THRESHOLD: log(1+e^a) ~= a


def _softplus(a: float) -> float:
    """log(1 + e^a), numerically stable for large a (matches the driver)."""
    if a > _SOFTPLUS_THRESHOLD:
        return a
    return math.log1p(math.exp(a))


def jump_rate(smooth: float, midpoint: float, rawaccel_clamp: bool) -> float:
    """Smoothing rate r = 2*pi / (smooth*midpoint).

    rawaccel_clamp=True reproduces RawAccel's behaviour of collapsing to a hard
    step (r=0) whenever smooth*midpoint < 1. YeetMouse passes False.
    """
    prod = smooth * midpoint
    if prod <= 0.0:
        return 0.0
    if rawaccel_clamp and prod < 1.0:
        return 0.0
    return (2.0 * math.pi) / prod


def sensitivity_ratio(cfg: JumpConfig, speed: float, *, rawaccel_clamp: bool) -> float:
    """f(speed): the sensitivity multiplier the raw delta is scaled by."""
    if speed <= 0.0:
        return 1.0
    a1 = cfg.accel - 1.0
    r = jump_rate(cfg.smooth, cfg.midpoint, rawaccel_clamp)

    if not cfg.gain:  # legacy / sensitivity variant
        if r != 0.0:
            arg = r * (cfg.midpoint - speed)
            if arg > 700.0:      # exp overflow guard -> denom huge -> f -> 1
                return 1.0
            if arg < -700.0:     # -> denom ~1 -> f -> accel
                return cfg.accel
            return 1.0 + a1 / (1.0 + math.exp(arg))
        return 1.0 if speed < cfg.midpoint else cfg.accel

    # gain variant
    if r != 0.0:
        def antideriv(x: float) -> float:
            return a1 * (x + _softplus(r * (cfg.midpoint - x)) / r)
        return 1.0 + (antideriv(speed) - antideriv(0.0)) / speed
    if speed < cfg.midpoint:
        return 1.0
    return 1.0 + a1 * (speed - cfg.midpoint) / speed


def applied_sensitivity(cfg: JumpConfig, speed: float, *, rawaccel_clamp: bool) -> float:
    return cfg.sensitivity * sensitivity_ratio(cfg, speed, rawaccel_clamp=rawaccel_clamp)


# --- speed helpers ----------------------------------------------------------
# A steady physical hand speed v (cm/s) at dpi produces, in counts/ms:
#   counts_per_ms = v[cm/s] * (dpi / 2.54)[counts/cm] / 1000
#   => v = counts_per_ms * 2540 / dpi
def counts_per_ms_to_cm_s(cpm: float, dpi: int) -> float:
    return cpm * 2540.0 / dpi


def cm_s_to_counts_per_ms(cm_s: float, dpi: int) -> float:
    return cm_s * dpi / 2540.0


# --- DPI compensation -------------------------------------------------------
def dpi_compensate(cfg: JumpConfig, new_dpi: int) -> JumpConfig:
    """Rescale params so the *physical* feel is identical at a different DPI.

    counts/ms scales linearly with DPI, so:
        midpoint     *= new/old   (threshold lands at the same hand speed)
        sensitivity  *= old/new   (same physical cm/360 at base sens)
        accel, smooth, gain        unchanged  (ratios / shape-invariant)
    """
    k = new_dpi / cfg.dpi
    return replace(
        cfg,
        midpoint=cfg.midpoint * k,
        sensitivity=cfg.sensitivity / k,
        dpi=new_dpi,
    )


# --- subcommands ------------------------------------------------------------
def _speed_grid(max_speed: float, n: int) -> list[float]:
    return [max_speed * i / (n - 1) for i in range(n)]


def cmd_curve(cfg: JumpConfig, tool: str, max_speed: float) -> None:
    clamp = tool == "raw"
    print(f"# {tool} Jump curve  midpoint={cfg.midpoint} accel={cfg.accel} "
          f"smooth={cfg.smooth} sens={cfg.sensitivity} gain={cfg.gain} dpi={cfg.dpi}")
    print(f"{'speed(c/ms)':>11} {'hand(cm/s)':>10} {'ratio':>8} {'applied':>8}  curve")
    grid = _speed_grid(max_speed, 24)
    lo, hi = cfg.sensitivity, cfg.sensitivity * cfg.accel
    span = (hi - lo) or 1.0
    for s in grid:
        ratio = sensitivity_ratio(cfg, s, rawaccel_clamp=clamp)
        appl = cfg.sensitivity * ratio
        bar = int(round(40 * (appl - lo) / span))
        bar = max(0, min(40, bar))
        print(f"{s:11.2f} {counts_per_ms_to_cm_s(s, cfg.dpi):10.1f} "
              f"{ratio:8.4f} {appl:8.4f}  {'#' * bar}")


def cmd_convert(cfg: JumpConfig, src: str, dst: str, to_dpi: int | None) -> None:
    out = cfg if to_dpi is None or to_dpi == cfg.dpi else dpi_compensate(cfg, to_dpi)
    src_l, dst_l = src.upper(), dst.upper()
    print(f"# {src_l} -> {dst_l}")
    if to_dpi and to_dpi != cfg.dpi:
        print(f"# DPI-compensated {cfg.dpi} -> {to_dpi} dpi (preserves physical feel)")
    smooth_label = {"raw": "Smooth", "yeet": "Smoothness"}[dst]
    mid_label = {"raw": "Input", "yeet": "Midpoint"}[dst]
    out_label = {"raw": "Output", "yeet": "Acceleration"}[dst]
    sens_label = {"raw": "Sens Multiplier", "yeet": "Sensitivity X"}[dst]
    gain_label = {"raw": "Gain", "yeet": "Use Smoothing"}[dst]
    print(f"  Mode            : Jump")
    print(f"  {mid_label:<15} : {out.midpoint:g}")
    print(f"  {out_label:<15} : {out.accel:g}")
    print(f"  {sens_label:<15} : {out.sensitivity:g}")
    print(f"  {smooth_label:<15} : {out.smooth:g}")
    print(f"  {gain_label:<15} : {'ON' if out.gain else 'OFF'}")
    # caveat: the RawAccel smoothing clamp
    prod = out.smooth * out.midpoint
    if dst == "raw" and 0 < prod < 1:
        print(f"  ! WARNING: smooth*midpoint = {prod:.3f} < 1 -> RawAccel collapses this "
              f"to a HARD step.\n  !          YeetMouse would render a steep sigmoid here. "
              f"Set Smooth >= {1.0 / out.midpoint:.4f} to keep a smooth jump,")
        print(f"  !          or accept the hard step (set YeetMouse Smoothness 0 to match exactly).")


def cmd_diff(yeet: JumpConfig, raw: JumpConfig, max_speed: float) -> None:
    """Quantify divergence between a concrete YeetMouse and RawAccel config."""
    if yeet.dpi != raw.dpi:
        print(f"# NOTE: DPI differs ({yeet.dpi} vs {raw.dpi}). Comparing on a shared "
              f"PHYSICAL hand-speed axis (cm/s).")
    grid = _speed_grid(max_speed, 400)
    worst = (0.0, 0.0, 0.0, 0.0)  # cm/s, yeet_appl, raw_appl, abs_rel_diff
    sse = 0.0
    for cm_s in grid:
        sy = cm_s_to_counts_per_ms(cm_s, yeet.dpi)
        sr = cm_s_to_counts_per_ms(cm_s, raw.dpi)
        ay = applied_sensitivity(yeet, sy, rawaccel_clamp=False)
        ar = applied_sensitivity(raw, sr, rawaccel_clamp=True)
        rel = abs(ay - ar) / max(ar, 1e-9)
        sse += (ay - ar) ** 2
        if rel > worst[3]:
            worst = (cm_s, ay, ar, rel)
    rms = math.sqrt(sse / len(grid))
    print(f"# YeetMouse vs RawAccel  (hand speed 0..{counts_per_ms_to_cm_s(max_speed, yeet.dpi):.0f} cm/s)")
    print(f"  RMS applied-sensitivity difference : {rms:.5f}")
    print(f"  Max relative difference            : {worst[3] * 100:.2f}%  "
          f"at {worst[0]:.1f} cm/s  (yeet={worst[1]:.4f} raw={worst[2]:.4f})")
    if worst[3] < 0.01:
        print("  => Effectively identical (<1%). Any felt difference is DPI / polling / "
              "Windows pointer settings, NOT the curve.")
    else:
        print("  => Curves diverge; inspect with the 'curve' subcommand on each tool.")


# --- Windows OS pointer pipeline -------------------------------------------
# The Windows "pointer speed" slider applies a LINEAR multiplier on top of
# RawAccel (EPP off). Registry HKCU\Control Panel\Mouse\MouseSensitivity:
#   10 (6th notch) is the ONLY 1:1 value. Source: Microsoft / MarkC table.
_SLIDER = {1: 0.1, 2: 0.2, 4: 0.4, 6: 0.6, 8: 0.8,
           10: 1.0, 12: 1.5, 14: 2.0, 16: 2.5, 18: 3.0, 20: 3.5}


def slider_mult(mouse_sensitivity: int) -> float:
    if mouse_sensitivity not in _SLIDER:
        raise SystemExit(f"non-standard MouseSensitivity={mouse_sensitivity} (expected one "
                         f"of {sorted(_SLIDER)})")
    return _SLIDER[mouse_sensitivity]


def windows_per_count(raw_speed: float, *, sens: float, midpoint: float, accel: float,
                      smooth: float, gain: bool, dpi_typed: float, slider: float) -> float:
    """Effective output-per-input-count on Windows, including RawAccel 1.7 DPI
    normalization and the Windows slider. RawAccel normalizes counts/ms to a
    1000-DPI reference using the *typed* device DPI, so both the curve input
    AND the base sens are scaled by 1000/dpi_typed when normalization is on."""
    if dpi_typed and dpi_typed > 0:
        norm_speed = raw_speed * 1000.0 / dpi_typed
        base = sens * 1000.0 / dpi_typed
    else:                       # normalization off -> raw counts/ms, like YeetMouse
        norm_speed = raw_speed
        base = sens
    curve = JumpConfig(midpoint=midpoint, accel=accel, smooth=smooth, sensitivity=1.0, gain=gain)
    return base * sensitivity_ratio(curve, norm_speed, rawaccel_clamp=True) * slider


def linux_per_count(raw_speed: float, *, sens: float, midpoint: float, accel: float,
                    smooth: float, gain: bool) -> float:
    """YeetMouse + KDE-flat: pure counts/ms, no normalization, no OS multiplier."""
    curve = JumpConfig(midpoint=midpoint, accel=accel, smooth=smooth, sensitivity=1.0, gain=gain)
    return sens * sensitivity_ratio(curve, raw_speed, rawaccel_clamp=False)


def cmd_port(max_speed: float) -> None:
    """Diagnose the live ryzen config and emit the RawAccel fix to match Linux.

    Hard-coded to the values read from the machine on 2026-06-10:
      Linux  YeetMouse: jump, sens 0.5, midpoint 7.8, accel 2.0, smooth 0 (hard step)
      Windows RawAccel : jump, sens 0.5, input 7.8, output 2.0, smooth 0,
                         device-DPI normalization = 1600, Windows slider = 1.5x (MouseSensitivity 12)
    Same physical mouse, same onboard DPI on both -> raw counts/ms are identical,
    so the only divergence is RawAccel's normalization + the slider.
    """
    lin = dict(sens=0.5, midpoint=7.8, accel=2.0, smooth=0.0, gain=False)
    print("# Effective sensitivity ratio  Windows / Linux  (1.00 == identical feel)")
    print(f"{'raw c/ms':>9} {'Linux':>8} {'Win now':>8} {'ratio':>7}   {'Win fixed':>9} {'ratio':>7}")
    worst = 1e9
    for raw in _speed_grid(max_speed, 21):
        l = linux_per_count(raw, **lin)
        w_now = windows_per_count(raw, sens=0.5, midpoint=7.8, accel=2.0, smooth=0.0,
                                  gain=False, dpi_typed=1600, slider=1.5)
        w_fix = windows_per_count(raw, sens=0.5, midpoint=7.8, accel=2.0, smooth=0.0,
                                  gain=False, dpi_typed=0, slider=1.0)
        rn = w_now / l if l else 1.0
        rf = w_fix / l if l else 1.0
        worst = min(worst, rn) if raw > 0 else worst
        print(f"{raw:9.2f} {l:8.4f} {w_now:8.4f} {rn:7.3f}   {w_fix:9.4f} {rf:7.3f}")
    print(f"\n  Current Windows is as slow as {worst*100:.0f}% of Linux in the mid-speed band "
          f"(boost fires 1.6x too late).")
    print("  Fixed Windows ratio is 1.000 at every speed.\n")
    print("  === Make Windows match Linux ===")
    print("  RawAccel (GUI):  device DPI normalization -> 0/OFF for the Logitech Receiver")
    print("                   Sens Multiplier 0.5 | Input 7.8 | Output 2.0 | Smooth 0 | Jump | Gain OFF")
    print("  Windows slider:  Mouse > Pointer Options > 6th notch  (registry MouseSensitivity = 10)")
    print("                   Enhance pointer precision: OFF (already correct)")


def _add_jump_args(p: argparse.ArgumentParser) -> None:
    p.add_argument("--midpoint", type=float, default=7.8, help="YeetMouse Midpoint / RawAccel Input")
    p.add_argument("--accel", type=float, default=2.0, help="YeetMouse Acceleration / RawAccel Output")
    p.add_argument("--smooth", type=float, default=0.0, help="YeetMouse Smoothness / RawAccel Smooth")
    p.add_argument("--sens", type=float, default=0.5, help="YeetMouse Sensitivity X / RawAccel Sens Multiplier")
    p.add_argument("--gain", action="store_true", help="gain variant (YeetMouse Use Smoothing / RawAccel Gain)")
    p.add_argument("--dpi", type=int, default=800, help="mouse DPI on this machine")


def _cfg_from(ns: argparse.Namespace) -> JumpConfig:
    return JumpConfig(ns.midpoint, ns.accel, ns.smooth, ns.sens, ns.gain, ns.dpi)


def main() -> None:
    ap = argparse.ArgumentParser(
        description="Match YeetMouse (Linux) and RawAccel (Windows) mouse acceleration.")
    sub = ap.add_subparsers(dest="cmd", required=True)

    c = sub.add_parser("curve", help="print sensitivity-vs-speed table + ASCII curve")
    c.add_argument("--tool", choices=["yeet", "raw"], default="yeet")
    c.add_argument("--max-speed", type=float, default=20.0, help="max counts/ms on the axis")
    _add_jump_args(c)

    v = sub.add_parser("convert", help="map params from one tool to the other (+ optional DPI compensate)")
    v.add_argument("--from", dest="src", choices=["yeet", "raw"], required=True)
    v.add_argument("--to", dest="dst", choices=["yeet", "raw"], required=True)
    v.add_argument("--to-dpi", type=int, default=None, help="target DPI (rescales for identical physical feel)")
    _add_jump_args(v)

    d = sub.add_parser("diff", help="quantify divergence between a YeetMouse and a RawAccel config")
    d.add_argument("--max-speed", type=float, default=20.0)
    for side in ("yeet", "raw"):
        d.add_argument(f"--{side}-midpoint", type=float, default=7.8)
        d.add_argument(f"--{side}-accel", type=float, default=2.0)
        d.add_argument(f"--{side}-smooth", type=float, default=(0.01 if side == "yeet" else 0.0))
        d.add_argument(f"--{side}-sens", type=float, default=0.5)
        d.add_argument(f"--{side}-gain", action="store_true")
        d.add_argument(f"--{side}-dpi", type=int, default=800)

    p = sub.add_parser("port", help="diagnose ryzen Windows-vs-Linux mismatch + emit the fix")
    p.add_argument("--max-speed", type=float, default=20.0)

    ns = ap.parse_args()
    if ns.cmd == "port":
        cmd_port(ns.max_speed)
    elif ns.cmd == "curve":
        cmd_curve(_cfg_from(ns), ns.tool, ns.max_speed)
    elif ns.cmd == "convert":
        cmd_convert(_cfg_from(ns), ns.src, ns.dst, ns.to_dpi)
    elif ns.cmd == "diff":
        yeet = JumpConfig(ns.yeet_midpoint, ns.yeet_accel, ns.yeet_smooth,
                          ns.yeet_sens, ns.yeet_gain, ns.yeet_dpi)
        raw = JumpConfig(ns.raw_midpoint, ns.raw_accel, ns.raw_smooth,
                         ns.raw_sens, ns.raw_gain, ns.raw_dpi)
        cmd_diff(yeet, raw, ns.max_speed)


if __name__ == "__main__":
    main()
