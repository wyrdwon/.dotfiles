#!/bin/zsh

# ── MP4 compressor ──────────────────────────────────────────────────────────
# compress_mp4 [-t tier] [-c crf] [-p preset] [-a bitrate|copy] [-s height|0]
#              [-o outdir] [-h] file [file...]
#
# Tiers set (crf, preset, audio, scale-cap-height) together; any explicit
# flag overrides just that one field, tier or no tier.
#
#   light      crf=18 preset=slow   audio=copy  scale=none   (visually lossless)
#   balanced   crf=23 preset=medium audio=copy  scale=none   (default, safe daily use)
#   aggressive crf=28 preset=medium audio=128k  scale=none   (audio now re-encoded)
#   extreme    crf=32 preset=fast   audio=96k   scale=720    (caps height, never upscales)
compress_mp4() {
  local tier="balanced" crf="" preset="" audio="" scale="" outdir=""

  _compress_mp4_help() {
    cat <<'EOF'
compress_mp4 — batch MP4 compressor over ffmpeg/libx264

USAGE
  compress_mp4 [options] file [file...]

OPTIONS
  -t, --tier TIER      light | balanced | aggressive | extreme   (default: balanced)
  -c, --crf N           override CRF (lower = higher quality/size)
  -p, --preset NAME     override x264 preset (ultrafast..veryslow)
  -a, --audio BITRATE   override audio: a bitrate like "128k", or "copy"
  -s, --scale HEIGHT    cap output height (e.g. 720); 0 disables scaling
  -o, --outdir DIR      write outputs here instead of alongside each input
  -h, --help            show this help

TIERS (crf / preset / audio / scale-cap)
  light        18 / slow   / copy / none   — visually lossless
  balanced     23 / medium / copy / none   — default
  aggressive   28 / medium / 128k / none   — audio re-encoded
  extreme      32 / fast   / 96k  / 720    — audio + resolution both reduced

Any explicit flag overrides that one field regardless of tier, e.g.:
  compress_mp4 -t extreme -a copy clip.mp4    # extreme, but keep lossless audio

EXAMPLES
  compress_mp4 movie.mp4
  compress_mp4 -t aggressive *.mp4
  compress_mp4 -t extreme -o ~/compressed episode1.mp4 episode2.mp4
EOF
  }

  # ---- arg parsing: flags first, then a file list -------------------------
  while [[ $# -gt 0 ]]; do
    case "$1" in
    -t | --tier)
      tier=$2
      shift 2
      ;;
    -c | --crf)
      crf=$2
      shift 2
      ;;
    -p | --preset)
      preset=$2
      shift 2
      ;;
    -a | --audio)
      audio=$2
      shift 2
      ;;
    -s | --scale)
      scale=$2
      shift 2
      ;;
    -o | --outdir)
      outdir=$2
      shift 2
      ;;
    -h | --help)
      _compress_mp4_help
      return 0
      ;;
    --)
      shift
      break
      ;;
    -*)
      echo "compress_mp4: unknown flag '$1' (see -h)" >&2
      return 1
      ;;
    *) break ;;
    esac
  done
  (($# == 0)) && {
    echo "compress_mp4: no input files (see -h)" >&2
    return 1
  }
  command -v ffmpeg >/dev/null || {
    echo "compress_mp4: ffmpeg not found" >&2
    return 1
  }

  # ---- tier defaults, only filling fields not explicitly overridden -------
  local d_crf d_preset d_audio d_scale
  case "$tier" in
  light) d_crf=18 d_preset=slow d_audio=copy d_scale=0 ;;
  balanced) d_crf=23 d_preset=medium d_audio=copy d_scale=0 ;;
  aggressive) d_crf=28 d_preset=medium d_audio=128k d_scale=0 ;;
  extreme) d_crf=32 d_preset=fast d_audio=96k d_scale=720 ;;
  *)
    echo "compress_mp4: unknown tier '$tier' (see -h)" >&2
    return 1
    ;;
  esac
  crf=${crf:-$d_crf} preset=${preset:-$d_preset}
  audio=${audio:-$d_audio} scale=${scale:-$d_scale}

  # ---- portable filesize -----------------------------------------------
  _filesize() { stat -c%s "$1" 2>/dev/null || stat -f%z "$1" 2>/dev/null; }

  local in size_in size_out audio_args scale_args out ok=0 fail=0
  for in in "$@"; do
    if [[ ! -f "$in" ]]; then
      echo "skip: '$in' not found" >&2
      ((fail++))
      continue
    fi

    [[ "$audio" == "copy" ]] && audio_args=(-c:a copy) ||
      audio_args=(-c:a aac -b:a "$audio")
    if [[ "$scale" != "0" ]]; then
      scale_args=(-vf "scale=-2:'min(ih,${scale})'")
    else
      scale_args=()
    fi

    local dest_dir=${outdir:-$(dirname "$in")}
    mkdir -p "$dest_dir" 2>/dev/null
    out="${dest_dir}/[compressed] $(basename "$in")"

    size_in=$(_filesize "$in")
    if ffmpeg -y -i "$in" -c:v libx264 -preset "$preset" -crf "$crf" \
      -pix_fmt yuv420p -movflags +faststart \
      "${scale_args[@]}" "${audio_args[@]}" "$out" \
      -loglevel error -stats </dev/null; then
      size_out=$(_filesize "$out")
      local pct=$((100 - (size_out * 100 / size_in)))
      printf 'ok: %s  (%s → %s, -%s%%)\n' \
        "$(basename "$in")" \
        "$(numfmt --to=iec "$size_in" 2>/dev/null || echo "${size_in}B")" \
        "$(numfmt --to=iec "$size_out" 2>/dev/null || echo "${size_out}B")" \
        "$pct"
      ((ok++))
    else
      echo "fail: $(basename "$in")" >&2
      ((fail++))
    fi
  done

  echo "compress_mp4: ${ok} ok, ${fail} failed"
  ((fail == 0))
}

# PDF compressor
pdf_compress() {
  local input="$1"
  local output="${2:-compressed.pdf}"
  local quality="${3:-ebook}"

  if [[ "$quality" == "mono" ]]; then
    gs \
      -sDEVICE=pdfwrite \
      -dCompatibilityLevel=1.4 \
      -dNOPAUSE \
      -dQUIET \
      -dBATCH \
      -sColorConversionStrategy=Gray \
      -dProcessColorModel=/DeviceGray \
      -dMonoImageDownsampleType=/Subsample \
      -dMonoImageResolution=200 \
      -dEncodeMonoImages=true \
      -dMonoImageFilter=/CCITTFaxEncode \
      -sOutputFile="$output" \
      "$input"
  else
    gs \
      -sDEVICE=pdfwrite \
      -dCompatibilityLevel=1.4 \
      -dPDFSETTINGS="/${quality}" \
      -dNOPAUSE \
      -dQUIET \
      -dBATCH \
      -sOutputFile="$output" \
      "$input"
  fi
}
