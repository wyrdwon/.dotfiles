#!/usr/bin/env python3
"""
smart_compress.py

Single-file, pedagogical implementation of the `smart_compress` pipeline described.

Purpose
-------
Provide a deterministic, adaptable, and well-commented Python implementation
that accepts a file, list of files, or a folder and runs a "smart" compression
pipeline using ffmpeg and ffprobe. It focuses on producing excellent compression
(first priority) while keeping heuristics deterministic and explainable.

Limitations / Notes
-------------------
- This script shells out to `ffprobe` and `ffmpeg`. It assumes they are on PATH.
- This is an engineering skeleton: extensible, testable, and intended for
  iterative improvement. It does not embed every optimization (e.g., SVT-AV1
  special handling) but provides connect points for them.
- VMAF computation is optional and gated; you must have `vmafossexec` on PATH
  (or adapt to your environment) if you enable that check.

Usage (simple)
---------------
python smart_compress.py --input /path/to/file.mp4

Or import `smart_compress` and call `smart_compress(paths, **kwargs)` from another
script.

The file is heavily documented so you understand why each decision exists.

"""

from __future__ import annotations

import argparse
import concurrent.futures
import json
import os
import random
import shlex
import shutil
import subprocess
import sys
import tempfile
import time
from dataclasses import dataclass, asdict
from pathlib import Path
from typing import Dict, List, Optional, Tuple

# -------------------------
# Configuration & Constants
# -------------------------

# Deterministic seed for any sampling used in heuristics. Keeps output
# deterministic across runs on same input.
DETERMINISTIC_SEED = 42

# Frame sampling: we deterministically sample these percent points of the
# duration to compute heuristics (noise, motion, detail). N=9 is a decent
# tradeoff between coverage and I/O cost.
SAMPLE_PERCENTS = [i / 10.0 for i in range(0, 10)]  # 0.0, 0.1, ... 0.9

# Noise thresholds (numbers are empirical and conservative; tune them if you
# iteratively measure against your dataset). Measured as mean 16x16-block
# variance of luminance channel.
V_NOISE_LOW = 6.0
V_NOISE_MED = 14.0
V_NOISE_HIGH = 30.0

# Motion thresholds: mean frame-diff normalized (0..1-ish) between sampled
# frames. These are empirical; adjust to taste.
MOTION_LOW = 0.005
MOTION_HIGH = 0.035

# Base CRF per codec (x265 and libaom-av1 chosen here). These are starting
# points; final CRF will be adjusted by heuristics.
BASE_CRF_X265 = 22
BASE_CRF_AV1 = 30

# bpp heuristics for quality targets (approximate, used as sanity checks)
BPP_TARGETS = {
    'hevc': (0.05, 0.10),  # perceptual transparency range
    'av1': (0.03, 0.07),
}

# default worker calculation (we will default to CPU_COUNT // 2) but cap at 8
MAX_DEFAULT_WORKERS = 8

# JSONL logfile path default
DEFAULT_LOG_PATH = "smart_compress_log.jsonl"

# Timeout for ffprobe calls
FFPROBE_TIMEOUT = 15

# -------------------------
# Data models
# -------------------------

@dataclass
class ProbeResult:
    """Structured result of probing a media file with ffprobe."""
    path: str
    duration: float
    width: int
    height: int
    fps: float
    video_codec: Optional[str]
    pix_fmt: Optional[str]
    bit_depth: Optional[int]
    channels: Optional[int]
    audio_codec: Optional[str]
    is_vfr: bool
    color_primaries: Optional[str]
    color_trc: Optional[str]
    colorspace: Optional[str]
    # raw ffprobe json for debugging if needed
    raw: Optional[Dict] = None


@dataclass
class Fingerprint:
    """Heuristic fingerprint computed from sampled frames and metadata."""
    noise_mean: float
    noise_std: float
    motion_mean: float
    motion_std: float
    detail_mean: float
    detail_std: float
    palette_colors: int
    is_hdr: bool


@dataclass
class JobParams:
    """Derived encoder parameters for a single job."""
    codec: str  # 'hevc' or 'av1' (or 'copy')
    crf: int
    preset: str
    denoise_filter: Optional[str]
    pix_fmt: Optional[str]
    audio_codec: str
    audio_bitrate: str
    extra_x265_params: Optional[str] = None
    container: str = 'mp4'


@dataclass
class JobResult:
    input_path: str
    output_path: Optional[str]
    success: bool
    reason: Optional[str]
    metrics: Dict
    params: Optional[JobParams]


# -------------------------
# Utility: run subprocess
# -------------------------


def run_cmd(cmd: List[str], check: bool = True, timeout: Optional[int] = None) -> Tuple[int, str, str]:
    """Run command and return (returncode, stdout, stderr)."""
    # Convert args to strings for robust cross-version behavior
    cmd = [str(c) for c in cmd]
    proc = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    try:
        out, err = proc.communicate(timeout=timeout)
    except subprocess.TimeoutExpired:
        proc.kill()
        out, err = proc.communicate()
        if check:
            raise
    if check and proc.returncode != 0:
        raise subprocess.CalledProcessError(proc.returncode, cmd, out, err)
    return proc.returncode, out, err


# -------------------------
# 1) Intake & file discovery
# -------------------------


def gather_inputs(paths: List[str], recurse: bool = True) -> List[str]:
    """Resolve a mixture of files and directories into a list of file paths.

    - If a directory is provided, we optionally recurse and collect media-like
      files based on extension. We do a small extension whitelist to avoid
      scanning the entire FS for irrelevant things.
    - Returns absolute paths.
    """
    exts = {'.mp4', '.mkv', '.mov', '.avi', '.webm', '.m4v', '.ts', '.flv', '.mpg', '.mpeg'}
    out = []
    for p in paths:
        pth = Path(p)
        if pth.is_dir():
            if recurse:
                for fp in pth.rglob('*'):
                    if fp.suffix.lower() in exts and fp.is_file():
                        out.append(str(fp.resolve()))
            else:
                for fp in pth.iterdir():
                    if fp.suffix.lower() in exts and fp.is_file():
                        out.append(str(fp.resolve()))
        elif pth.is_file():
            out.append(str(pth.resolve()))
        else:
            # Path doesn't exist. We let later stages report this.
            out.append(str(p))
    return sorted(set(out))


# -------------------------
# 2) Probe: ffprobe wrapper
# -------------------------


def ffprobe(path: str) -> ProbeResult:
    """Run ffprobe and extract structured media properties.

    We keep probing robust: if ffprobe JSON is missing something we fall back
    to best-effort defaults. The function is defensive to real-world broken
    files.
    """
    if not Path(path).exists():
        raise FileNotFoundError(path)

    cmd = [
        'ffprobe', '-v', 'error',
        '-print_format', 'json',
        '-show_streams', '-show_format', path
    ]
    try:
        _, out, _ = run_cmd(cmd, check=True, timeout=FFPROBE_TIMEOUT)
        data = json.loads(out)
    except Exception as e:
        # If probing fails, raise with context
        raise RuntimeError(f"ffprobe failed for {path}: {e}")

    # default values
    duration = 0.0
    width = 0
    height = 0
    fps = 0.0
    video_codec = None
    pix_fmt = None
    bit_depth = None
    audio_codec = None
    channels = None
    is_vfr = False
    color_primaries = None
    color_trc = None
    colorspace = None

    # format-level duration
    fmt = data.get('format', {})
    if fmt:
        try:
            duration = float(fmt.get('duration', 0.0))
        except Exception:
            duration = 0.0

    # parse streams: pick video stream (first video) and first audio
    streams = data.get('streams', [])
    vstream = None
    astream = None
    for s in streams:
        if s.get('codec_type') == 'video' and vstream is None:
            vstream = s
        elif s.get('codec_type') == 'audio' and astream is None:
            astream = s
    if vstream:
        video_codec = vstream.get('codec_name')
        width = int(vstream.get('width', 0) or 0)
        height = int(vstream.get('height', 0) or 0)
        # parse fps string like '30000/1001' or '25/1'
        r_frame_rate = vstream.get('r_frame_rate') or vstream.get('avg_frame_rate')
        try:
            if r_frame_rate and '/' in r_frame_rate:
                num, den = r_frame_rate.split('/')
                fps = float(num) / float(den)
            elif r_frame_rate:
                fps = float(r_frame_rate)
        except Exception:
            fps = 0.0
        # pix_fmt / bit depth
        pix_fmt = vstream.get('pix_fmt')
        # guess bit depth from pix_fmt if present (e.g., yuv420p10le -> 10)
        if pix_fmt and any(ch.isdigit() for ch in pix_fmt):
            # naive parse: find number substring
            digits = ''.join([c for c in pix_fmt if c.isdigit()])
            if digits:
                bit_depth = int(digits)
        # color metadata
        color_primaries = vstream.get('color_primaries')
        color_trc = vstream.get('color_trc')
        colorspace = vstream.get('colorspace')
        # detect VFR if time_base or avg_frame_rate inconsistent
        # we'll conservatively set vfr True if avg_frame_rate is missing
        is_vfr = vstream.get('avg_frame_rate') is None or vstream.get('avg_frame_rate') == '0/0'

    if astream:
        audio_codec = astream.get('codec_name')
        channels = int(astream.get('channels', 0) or 0)

    return ProbeResult(
        path=path,
        duration=duration,
        width=width,
        height=height,
        fps=fps,
        video_codec=video_codec,
        pix_fmt=pix_fmt,
        bit_depth=bit_depth,
        channels=channels,
        audio_codec=audio_codec,
        is_vfr=is_vfr,
        color_primaries=color_primaries,
        color_trc=color_trc,
        colorspace=colorspace,
        raw=data,
    )


# -------------------------
# 3) Fingerprinting (frame sampling + heuristics)
# -------------------------


def sample_frames(path: str, probe: ProbeResult, percent_samples: List[float] = SAMPLE_PERCENTS) -> List[Path]:
    """Extract a small set of frame images deterministically to temporary files.

    We use percent-based seeking so VFR / weird timestamps are handled more
    robustly than "extract frame N" which depends on keyframes.

    Returns list of temporary PNG paths (caller must cleanup).
    """
    tmpdir = Path(tempfile.mkdtemp(prefix='smartcomp_frames_'))
    out_paths: List[Path] = []

    # If duration is 0 (weird file), fall back to grabbing first N frames.
    dur = probe.duration or 0.0

    for i, pct in enumerate(percent_samples):
        if dur > 0:
            t = max(0.0, pct * dur)
            # Use ffmpeg seeking with -ss before -i for fast keyframe seek, but
            # that gives nearest keyframe — we accept the small deviation for
            # speed. For better precision use -ss after -i but it's slower.
            out_fn = tmpdir / f'frame_{i}.png'
            cmd = [
                'ffmpeg', '-hide_banner', '-loglevel', 'error',
                '-ss', f'{t}', '-i', path,
                '-frames:v', '1', str(out_fn)
            ]
        else:
            # unknown duration: take the first N frames
            out_fn = tmpdir / f'frame_{i}.png'
            cmd = [
                'ffmpeg', '-hide_banner', '-loglevel', 'error',
                '-i', path, '-frames:v', '1', str(out_fn)
            ]
        try:
            run_cmd(cmd, check=True)
            out_paths.append(out_fn)
        except Exception as e:
            # If extraction fails, continue; the fingerprint function should be
            # robust to missing samples.
            print(f"warning: frame extraction failed at pct={pct}: {e}", file=sys.stderr)
    return out_paths


# Helper: compute simple image metrics using Pillow (import locally to avoid
# hard dependency if not needed). Pillow is helpful but we avoid complex
# libraries for portability. We'll import lazily.


def compute_frame_metrics(image_path: Path) -> Dict:
    """Return a dictionary of metrics for a single frame image.

    Metrics:
      - noise_block_var: mean block variance (16x16) on Y channel
      - laplacian_var: edge/detail variance (approx via simple Laplacian kernel)
      - unique_colors: unique color count on a downsampled thumbnail

    This function keeps calculations simple and deterministic. It is not a
    statistical masterwork but good enough for routing decisions.
    """
    try:
        from PIL import Image, ImageFilter
        import numpy as np
    except Exception:
        raise RuntimeError("Pillow and numpy are required for frame metrics: pip install pillow numpy")

    im = Image.open(str(image_path)).convert('RGB')
    w, h = im.size
    # convert to Y (luma) using quick BT.601-like conversion
    arr = np.asarray(im).astype(np.float32)
    # Y = 0.299R + 0.587G + 0.114B
    Y = 0.299 * arr[..., 0] + 0.587 * arr[..., 1] + 0.114 * arr[..., 2]

    # Block variance: tile image into 16x16 blocks, compute variance of each
    tile = 16
    block_vars = []
    for y0 in range(0, h, tile):
        for x0 in range(0, w, tile):
            block = Y[y0:min(y0 + tile, h), x0:min(x0 + tile, w)]
            if block.size == 0:
                continue
            block_vars.append(float(block.var()))
    noise_mean = float(np.mean(block_vars)) if block_vars else 0.0
    noise_std = float(np.std(block_vars)) if block_vars else 0.0

    # Laplacian variance (approx): use PIL's FIND_EDGES as cheap proxy and
    # compute variance. True Laplacian would be better but this is fast.
    edges = im.filter(ImageFilter.FIND_EDGES).convert('L')
    edges_arr = np.asarray(edges).astype(np.float32)
    lap_var = float(edges_arr.var())

    # unique colors on a thumbnail (downsample to limit memory)
    thumb = im.copy()
    thumb.thumbnail((256, 256))
    uq = len(thumb.convert('P', palette=Image.ADAPTIVE, colors=4096).getcolors(4096) or [])

    return {
        'noise_mean': noise_mean,
        'noise_std': noise_std,
        'laplacian_var': lap_var,
        'unique_colors': uq,
    }


def fingerprint_from_samples(frame_paths: List[Path], probe: ProbeResult) -> Fingerprint:
    """Compute the aggregated fingerprint from sampled frames and probe metadata.

    This reduces the sampled metrics into means and stds for next-stage
    decision routing.
    """
    metrics = []
    for p in frame_paths:
        try:
            m = compute_frame_metrics(p)
            metrics.append(m)
        except Exception as e:
            print(f"warning: failed to compute metrics for {p}: {e}", file=sys.stderr)
    # Remove temporary files (we keep the directory; caller cleans it) -- but
    # we'll leave cleanup to the caller of sample_frames which created the tmpdir.

    if not metrics:
        # conservative fallback: low motion, low noise
        return Fingerprint(
            noise_mean=0.0,
            noise_std=0.0,
            motion_mean=0.0,
            motion_std=0.0,
            detail_mean=0.0,
            detail_std=0.0,
            palette_colors=0,
            is_hdr=bool(probe.bit_depth and probe.bit_depth >= 10)
        )

    import numpy as np

    noise_means = [m['noise_mean'] for m in metrics]
    lap_vars = [m['laplacian_var'] for m in metrics]
    palettes = [m['unique_colors'] for m in metrics]

    # motion estimate: compare consecutive frames using simple mean absolute
    # difference over RGB thumbnails. We reconstruct the frames from paths
    # again, but for determinism we reuse the same function. For performance
    # this could be done while computing the other metrics.
    motion_vals = []
    frames_arrs = []
    from PIL import Image
    for p in frame_paths:
        try:
            im = Image.open(p).convert('RGB')
            im.thumbnail((320, 240))
            frames_arrs.append(np.asarray(im).astype(np.float32))
        except Exception:
            frames_arrs.append(None)

    for a, b in zip(frames_arrs[:-1], frames_arrs[1:]):
        if a is None or b is None:
            continue
        # mean abs diff normalized by 255
        mad = float(np.mean(np.abs(a - b))) / 255.0
        motion_vals.append(mad)

    motion_mean = float(np.mean(motion_vals)) if motion_vals else 0.0
    motion_std = float(np.std(motion_vals)) if motion_vals else 0.0

    return Fingerprint(
        noise_mean=float(np.mean(noise_means)),
        noise_std=float(np.std(noise_means)),
        motion_mean=motion_mean,
        motion_std=motion_std,
        detail_mean=float(np.mean(lap_vars)),
        detail_std=float(np.std(lap_vars)),
        palette_colors=int(np.mean(palettes)),
        is_hdr=bool(probe.bit_depth and probe.bit_depth >= 10) or bool(probe.color_trc in ('smpte2084', 'pq', 'smpte2086'))
    )


# -------------------------
# 4) Profile classifier
# -------------------------


def classify_profile(probe: ProbeResult, fp: Fingerprint) -> str:
    """Map probe + fingerprint to a canonical profile.

    Returns one of: 'screen', 'anime', 'camera', 'cinema', 'surveillance', 'scientific'

    The mapping is rule-based (deterministic). These rules are conservative by
    design to prioritize visual fidelity.
    """
    # Screen detection: low unique colors and lots of edges / high edge density
    is_screen = (fp.palette_colors < 2000 and fp.detail_mean > 200)

    # Anime detection: moderate palette with sharp edges and low noise
    is_anime = (fp.palette_colors < 6000 and fp.noise_mean < V_NOISE_MED and fp.detail_mean > 150)

    # Surveillance: low motion, low resolution, often high noise
    is_surveillance = (probe.width <= 640 and fp.motion_mean < MOTION_LOW)

    # Cinema: high detail, intentional grain; prefer to avoid denoise
    is_cinema = (fp.noise_mean >= V_NOISE_MED and fp.detail_mean > 250)

    # Scientific: often requires exactness; heuristics aren't perfect. We detect
    # for tiny scenes where pixel exactness matters via low palette but high
    # detail plus codec==raw-like - user override is needed in general.
    is_scientific = False

    # Camera: default fallback for typical camera footage
    if is_screen:
        return 'screen'
    if is_anime:
        return 'anime'
    if is_surveillance:
        return 'surveillance'
    if is_cinema:
        return 'cinema'
    if is_scientific:
        return 'scientific'
    return 'camera'


# -------------------------
# 5) Parameter derivation
# -------------------------


def derive_params(profile: str, probe: ProbeResult, fp: Fingerprint, codec_pref: List[str]) -> JobParams:
    """Derive deterministic encoder params based on profile, probe, and fingerprint.

    codec_pref is an ordered preference list, e.g. ['hevc', 'av1'].
    """
    # Choose codec based on preference and compatibility hints
    chosen_codec = None
    # If HDR, prefer hevc (safer) but av1 is ok too depending on preference
    if fp.is_hdr and 'hevc' in codec_pref:
        chosen_codec = 'hevc'
    else:
        # pick first preferred codec
        chosen_codec = codec_pref[0]

    # base CRF
    if chosen_codec == 'hevc':
        crf = BASE_CRF_X265
    elif chosen_codec == 'av1':
        crf = BASE_CRF_AV1
    else:
        crf = BASE_CRF_X265

    # profile-specific base adjustments
    if profile == 'screen':
        crf += 4  # screen content tolerates higher CRF
        preset = 'veryslow'
    elif profile == 'anime':
        crf -= 2
        preset = 'slower'
    elif profile == 'camera':
        crf = max(17, crf)  # avoid too-high crf for camera footage
        preset = 'slower'
    elif profile == 'cinema':
        crf -= 3
        preset = 'slower'
    elif profile == 'surveillance':
        crf += 6
        preset = 'slow'
    elif profile == 'scientific':
        crf = 12  # preserve as much detail as possible
        preset = 'slow'
    else:
        preset = 'slower'

    # noise-based adjustments: if noise is high, we prefer to denoise then
    # possibly increase CRF (because denoised video compresses much better).
    denoise = None
    if fp.noise_mean >= V_NOISE_HIGH:
        # heavy noise -> use NLMeans (slow)
        denoise = 'nlmeans'  # mark which denoise operator we want (handled below)
        crf += 2  # after denoise we can raise CRF a touch
    elif fp.noise_mean >= V_NOISE_MED:
        denoise = 'hqdn3d=0.5:0.5:3:3'
        crf += 1

    # motion-based tweak: low motion => slightly lower CRF yields visible gains
    if fp.motion_mean < MOTION_LOW:
        crf = max(12, crf - 1)

    # enforce bit-depth: favor 10-bit for HDR and high-detail footage
    pix_fmt = None
    if fp.is_hdr or profile in ('camera', 'cinema'):
        pix_fmt = 'yuv420p10le'
    else:
        pix_fmt = 'yuv420p'

    # audio choices (conservative default)
    audio_codec = 'aac'
    audio_bitrate = '96k'
    if profile == 'screen':
        audio_bitrate = '64k'

    extra_x265 = None
    container = 'mp4' if chosen_codec == 'hevc' else 'mkv'

    return JobParams(
        codec=chosen_codec,
        crf=int(crf),
        preset=preset,
        denoise_filter=denoise,
        pix_fmt=pix_fmt,
        audio_codec=audio_codec,
        audio_bitrate=audio_bitrate,
        extra_x265_params=extra_x265,
        container=container,
    )


# -------------------------
# 6) Assemble ffmpeg command
# -------------------------


def build_ffmpeg_cmd(input_path: str, out_path: str, params: JobParams, probe: ProbeResult) -> List[str]:
    """Return a shell-args list for the ffmpeg invocation for given params.

    The function keeps commands explicit and deterministic. It is the single
    place to change encoder arguments for tuning.
    """
    cmd = ['ffmpeg', '-hide_banner', '-y', '-i', input_path]

    vf_parts = []
    if params.denoise_filter:
        if params.denoise_filter == 'nlmeans':
            # NLMeans is slow but high-quality (ffmpeg's builtin filter)
            vf_parts.append('nlmeans=7:7:3:3:0:0:0:0')
        else:
            vf_parts.append(params.denoise_filter)

    if vf_parts:
        cmd += ['-vf', ','.join(vf_parts)]

    # video codec selection
    if params.codec == 'hevc':
        # libx265 usage
        x265_params = f'crf={params.crf}:aq-mode=3:psy-rd=1.0'
        if params.extra_x265_params:
            x265_params += ':' + params.extra_x265_params
        cmd += ['-c:v', 'libx265', '-preset', params.preset, '-x265-params', x265_params]
        if params.pix_fmt:
            cmd += ['-pix_fmt', params.pix_fmt]
    elif params.codec == 'av1':
        # libaom-av1; we use -crf and -b:v 0 for pure quality mode
        cmd += ['-c:v', 'libaom-av1', '-crf', str(params.crf), '-b:v', '0', '-cpu-used', '1']
        if params.pix_fmt:
            cmd += ['-pix_fmt', params.pix_fmt]
    else:
        # fallback: copy stream (not recommended for compression goals)
        cmd += ['-c:v', 'copy']

    # audio
    if params.audio_codec == 'aac':
        cmd += ['-c:a', 'aac', '-b:a', params.audio_bitrate]
    elif params.audio_codec == 'opus':
        cmd += ['-c:a', 'libopus', '-b:a', params.audio_bitrate]
    else:
        cmd += ['-c:a', 'copy']

    # container
    out_file = out_path
    cmd += [out_file]
    return cmd


# -------------------------
# 7) Validation & metrics
# -------------------------


def compute_bpp(file_bytes: int, width: int, height: int, fps: float, duration: float) -> float:
    """Compute bits-per-pixel metric. Returns bpp (bits per pixel per frame).

    This is a convenient single-number proxy for compression level.
    """
    if duration <= 0 or width <= 0 or height <= 0 or fps <= 0:
        return 0.0
    total_pixels = width * height * fps * duration
    if total_pixels <= 0:
        return 0.0
    bits = file_bytes * 8
    return bits / total_pixels


def validate_output(input_path: str, output_path: str, probe_in: ProbeResult, vmaf_threshold: Optional[float] = None) -> Tuple[bool, Dict]:
    """Run quick validations on the output file.

    - Check duration close to original.
    - Compute bpp and attach to metrics.
    - Optionally run VMAF (if vmaf_threshold provided and vmafossexec usable).
    """
    if not Path(output_path).exists():
        return False, {'reason': 'output_missing'}
    try:
        pr = ffprobe(output_path)
    except Exception as e:
        return False, {'reason': f'probe_failed:{e}'}

    # duration check: allow small variance (0.1s or 0.5%)
    dur_in = probe_in.duration or 0.0
    dur_out = pr.duration or 0.0
    if dur_in > 0:
        if abs(dur_in - dur_out) > max(0.1, 0.005 * dur_in):
            return False, {'reason': f'duration_mismatch:in={dur_in},out={dur_out}'}

    size = Path(output_path).stat().st_size
    bpp = compute_bpp(size, pr.width, pr.height, pr.fps or probe_in.fps or 30.0, pr.duration or dur_in)

    metrics = {'size_bytes': size, 'bpp': bpp, 'width': pr.width, 'height': pr.height, 'fps': pr.fps}

    # Optional VMAF (requires vmafossexec and ffmpeg compiled with libvmaf).
    if vmaf_threshold is not None:
        # vmafossexec expects reference + distorted. We shell out to ffmpeg + libvmaf
        # usage is not stable across installs, so we guard carefully.
        try:
            # create temporary yuv files or let ffmpeg compute VMAF directly to stdout
            cmd = [
                'ffmpeg', '-i', input_path, '-i', output_path,
                '-lavfi', 'libvmaf=model_path=vmaf_v0.6.1.pkl',
                '-f', 'null', '-'  # run and get vmaf in stderr
            ]
            # This is an expensive op and many systems don't have libvmaf.
            # We attempt it and ignore errors.
            _, out, err = run_cmd(cmd, check=False, timeout=300)
            # parse vmaf score from stderr if present
            # naive parse: look for 'VMAF score: ' or 'VMAF score:0..'
            import re
            m = re.search(r'VMAF score:\s*([0-9.]+)', err)
            if m:
                v = float(m.group(1))
                metrics['vmaf'] = v
                if v < vmaf_threshold:
                    return False, {'reason': f'vmaf_below_threshold:{v}<{vmaf_threshold}', **metrics}
        except Exception:
            # ignore vmaf failures
            pass

    return True, metrics


# -------------------------
# 8) Job execution
# -------------------------


def run_job(input_path: str, out_dir: Optional[str], codec_pref: List[str], dry_run: bool = False, vmaf_threshold: Optional[float] = None) -> JobResult:
    """Single-file job: probe, fingerprint, derive params, build and run ffmpeg,
    validate output, and return JobResult.

    The function is intentionally linear for clarity; it can be split into
    smaller units if needed.
    """
    try:
        probe = ffprobe(input_path)
    except Exception as e:
        return JobResult(input_path=input_path, output_path=None, success=False, reason=str(e), metrics={}, params=None)

    # cheap skip: if the file is very small (<100KB) we don't touch it
    try:
        size = Path(input_path).stat().st_size
        if size < 100 * 1024:
            return JobResult(input_path=input_path, output_path=input_path, success=True, reason='skip_small', metrics={'size_bytes': size}, params=None)
    except Exception:
        pass

    # sample frames and fingerprint
    frame_paths = sample_frames(input_path, probe)
    try:
        fp = fingerprint_from_samples(frame_paths, probe)
    finally:
        # cleanup temporary frame folder(s)
        if frame_paths:
            tmpdir = frame_paths[0].parent
            try:
                shutil.rmtree(tmpdir)
            except Exception:
                pass

    # classify
    profile = classify_profile(probe, fp)

    # derive params
    params = derive_params(profile, probe, fp, codec_pref)

    # output path default
    in_path = Path(input_path)
    out_dir = Path(out_dir) if out_dir else in_path.parent
    out_name = in_path.stem + f'.smart.{params.codec}.' + params.container
    out_path = str(out_dir / out_name)

    # build command
    cmd = build_ffmpeg_cmd(input_path, out_path, params, probe)

    # dry-run: print the command and return success=False with dry-run tag
    if dry_run:
        return JobResult(input_path=input_path, output_path=out_path, success=False, reason='dry_run', metrics={'cmd': ' '.join(shlex.quote(p) for p in cmd)}, params=params)

    # execute
    try:
        t0 = time.time()
        run_cmd(cmd, check=True)
        elapsed = time.time() - t0
    except subprocess.CalledProcessError as e:
        return JobResult(input_path=input_path, output_path=None, success=False, reason=f'encode_failed:{e}', metrics={}, params=params)

    # validate
    ok, metrics = validate_output(input_path, out_path, probe, vmaf_threshold=vmaf_threshold)
    metrics['encode_time_s'] = elapsed

    if not ok:
        # basic retry strategy: reduce CRF (more quality) and try once more.
        # This is deterministic: we reduce by 1 and re-encode.
        if params.crf > 10:
            params2 = JobParams(**asdict(params))
            params2.crf = max(10, params2.crf - 1)
            out_path2 = str(out_dir / (in_path.stem + f'.smart.retry.{params2.codec}.' + params2.container))
            cmd2 = build_ffmpeg_cmd(input_path, out_path2, params2, probe)
            try:
                run_cmd(cmd2, check=True)
                ok2, metrics2 = validate_output(input_path, out_path2, probe, vmaf_threshold=vmaf_threshold)
                metrics2['encode_time_s'] = metrics.get('encode_time_s', 0) + (time.time() - t0)
                if ok2:
                    return JobResult(input_path=input_path, output_path=out_path2, success=True, reason='retry_ok', metrics=metrics2, params=params2)
            except Exception:
                pass
        return JobResult(input_path=input_path, output_path=out_path, success=False, reason='validation_failed', metrics=metrics, params=params)

    return JobResult(input_path=input_path, output_path=out_path, success=True, reason=None, metrics=metrics, params=params)


# -------------------------
# 9) Orchestration (parallel worker pool + logging)
# -------------------------


def smart_compress(inputs: List[str], out_dir: Optional[str] = None, codec_pref: Optional[List[str]] = None,
                   workers: Optional[int] = None, dry_run: bool = False, log_path: Optional[str] = None,
                   vmaf_threshold: Optional[float] = None) -> List[JobResult]:
    """Top-level function: compress a list of inputs (files or directories).

    - inputs: list of file paths and/or directories
    - out_dir: optional directory to place outputs
    - codec_pref: list like ['hevc', 'av1'] indicating encoder preference
    - workers: degree of parallelism
    - dry_run: if True, don't execute encodes, only print planned commands
    - log_path: JSONL path to append job results
    - vmaf_threshold: if given, validate outputs with VMAF threshold
    """
    codec_pref = codec_pref or ['hevc', 'av1']
    log_path = log_path or DEFAULT_LOG_PATH

    file_list = gather_inputs(inputs, recurse=True)

    if not file_list:
        print('No inputs found.', file=sys.stderr)
        return []

    # compute worker pool
    cpu_count = os.cpu_count() or 4
    if workers is None:
        workers = max(1, min(MAX_DEFAULT_WORKERS, cpu_count // 2))

    # deterministic ordering of files
    file_list = sorted(file_list)

    results: List[JobResult] = []

    # ensure the log file exists
    open(log_path, 'a').close()

    # use a ThreadPool because our work is mostly blocking on subprocesses.
    with concurrent.futures.ThreadPoolExecutor(max_workers=workers) as ex:
        futures = {
            ex.submit(run_job, f, out_dir, codec_pref, dry_run, vmaf_threshold): f for f in file_list
        }
        for fut in concurrent.futures.as_completed(futures):
            inp = futures[fut]
            try:
                res: JobResult = fut.result()
            except Exception as e:
                res = JobResult(input_path=inp, output_path=None, success=False, reason=str(e), metrics={}, params=None)
            results.append(res)
            # append result as JSONL
            with open(log_path, 'a', encoding='utf-8') as L:
                entry = {
                    'timestamp': time.time(),
                    'input': res.input_path,
                    'output': res.output_path,
                    'success': res.success,
                    'reason': res.reason,
                    'metrics': res.metrics,
                    'params': asdict(res.params) if res.params else None,
                }
                L.write(json.dumps(entry) + '\n')
            # print a short summary to stdout
            if res.success:
                print(f"[OK] {res.input_path} -> {res.output_path} ({res.metrics.get('size_bytes', '?')} bytes)")
            else:
                print(f"[FAIL] {res.input_path}: {res.reason}")

    return results


# -------------------------
# CLI
# -------------------------


def main(argv: Optional[List[str]] = None):
    p = argparse.ArgumentParser(prog='smart_compress', description='Smart video compressor (pedagogical).')
    p.add_argument('--input', '-i', required=True, nargs='+', help='Input file(s) or directories')
    p.add_argument('--out-dir', '-o', help='Directory to place outputs (default: same folder as inputs)')
    p.add_argument('--codec-pref', nargs='+', default=['hevc', 'av1'], help='Codec preference order (hevc av1)')
    p.add_argument('--workers', type=int, help='Number of parallel jobs (defaults to CPU/2)')
    p.add_argument('--dry-run', action='store_true', help='Do not execute ffmpeg; print planned commands')
    p.add_argument('--log', help='JSONL log path', default=DEFAULT_LOG_PATH)
    p.add_argument('--vmaf', type=float, help='Optional VMAF threshold for validation (expensive)')
    args = p.parse_args(argv)

    # deterministic seed for sampling
    random.seed(DETERMINISTIC_SEED)

    smart_compress(args.input, out_dir=args.out_dir, codec_pref=args.codec_pref, workers=args.workers, dry_run=args.dry_run, log_path=args.log, vmaf_threshold=args.vmaf)


if __name__ == '__main__':
    main()

