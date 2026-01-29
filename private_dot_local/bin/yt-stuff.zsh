#!/bin/zsh

# =========================================================
# yt-dlp wrapper
# =========================================================
_ytx() {
  local mode="$1"
  shift

  local BASE_OPTS=(
    --newline
    --embed-metadata
    --embed-thumbnail
    --merge-output-format mp4
    --no-playlist
  )

  case "$mode" in
    sd)
      yt-dlp "${BASE_OPTS[@]}" \
        -f 'bestvideo[height<=480]+bestaudio/best[height<=480]' \
        "$@"
      ;;
    hd)
      yt-dlp "${BASE_OPTS[@]}" \
        -f 'bestvideo[height<=1080]+bestaudio/best[height<=1080]' \
        "$@"
      ;;
    qhd)
      yt-dlp "${BASE_OPTS[@]}" \
        -f 'bestvideo[height<=1440]+bestaudio/best[height<=1440]' \
        "$@"
      ;;
    uhd)
      yt-dlp "${BASE_OPTS[@]}" \
        -f 'bestvideo[height<=2160]+bestaudio/best[height<=2160]' \
        "$@"
      ;;
    best)
      yt-dlp "${BASE_OPTS[@]}" \
        -f 'bestvideo+bestaudio/best' \
        "$@"
      ;;
    mp3)
      yt-dlp \
        --extract-audio \
        --audio-format mp3 \
        --audio-quality 0 \
        --embed-metadata \
        --embed-thumbnail \
        "$@"
      ;;
    *)
      echo "ytx: unknown mode '$mode'" >&2
      return 1
      ;;
  esac
}

# Public endpoints (the only ones users should touch)
yt-sd()   { _ytx sd   "$@"; }
yt-hd()   { _ytx hd   "$@"; }
yt-qhd()  { _ytx qhd  "$@"; }
yt-uhd()  { _ytx uhd  "$@"; }
yt-best() { _ytx best "$@"; }
yt-mp3()  { _ytx mp3  "$@"; }
