# README

A minimal utility for deterministic, content-aware video compression. It probes files or directories, fingerprints visual characteristics, selects an appropriate codec profile, and generates an ffmpeg command accordingly. The implementation favors clarity and extensibility over raw performance.

## Features

- Recursive file discovery
- ffprobe-based metadata extraction
- Deterministic fingerprinting (sampled frames, noise/motion/edges)
- Profile selection (screen, anime, camera, grainy, etc.)
- Auto-generated ffmpeg command for HEVC/AV1
- Dry-run and verbose modes

## Usage

```bash
python smart_compress.py /path/to/video_or_folder
```
