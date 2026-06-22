#!/bin/zsh

# MP4 compressor
compress_mp4() {
  local in=$1 crf=${2:-18}
  [[ -f $in ]] || return 1
  ffmpeg -i "$in" -c:v libx264 -preset slow -crf "$crf" \
    -pix_fmt yuv420p -movflags +faststart -c:a copy \
    "$(dirname "$in")/[compressed] $(basename "$in")"
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
