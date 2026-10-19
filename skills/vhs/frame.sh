#!/usr/bin/env bash
# Round the corners of a VHS screenshot or screencast and add a Carbon-style
# drop shadow (0 20px 68px rgba(0,0,0,0.55)).
#
# Usage: frame.sh <in.png|in.gif|in.mp4|in.webm> <out> [--bg <color>] [--radius <px>]
#                 [--hold <seconds>] [--no-trim]
#
# Empty rows below the last output are trimmed so the bottom padding matches
# the sides. Screencasts hold their last frame for --hold seconds (default: 2).
# PNG and WebP outputs keep a transparent background unless --bg is given.
# Other formats can't carry a soft shadow over transparency, so it is
# flattened onto --bg (default: white). The output format follows <out>'s
# extension.
set -euo pipefail

usage() { sed -n '2,13p' "$0" | sed 's/^# \{0,1\}//'; exit 2; }

[[ $# -ge 2 ]] || usage
in=$1 out=$2
shift 2
bg="" radius=14 hold=2 trim=1
while [[ $# -gt 0 ]]; do
	case $1 in
	--bg) bg=$2; shift 2 ;;
	--radius) radius=$2; shift 2 ;;
	--hold) hold=$2; shift 2 ;;
	--no-trim) trim=0; shift ;;
	*) usage ;;
	esac
done

blur=34 offset_y=20 opacity=0.55
pad_x=80 pad_top=60 pad_bottom=110
# VHS leaves an empty strip below the window buttons; must match style.tape's WindowBarSize.
bar=60 bar_gap=20

read -r w h < <(magick identify -format '%w %h\n' "$in" | head -1)
body_y=$((bar + bar_gap)) body=$((h - bar - bar_gap))

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

if ((trim)); then
	frames=("$in")
	if [[ ${in,,} != *.png ]]; then
		ffmpeg -loglevel error -i "$in" -vf fps=5 "$tmp/frame-%04d.png"
		frames=("$tmp"/frame-*.png)
	fi
	# %@ is each frame's content box, measured against the padding colour.
	read -r left bottom < <(magick "${frames[@]}" -crop "${w}x$body+0+$body_y" +repage -fuzz 10% -format '%@\n' info: |
		awk -F'[x+]' '$1 > 1 { if (l == "" || $3 < l) l = $3; if ($4 + $2 > b) b = $4 + $2 } END { print l, b }')
	[[ -n $left ]] && ((bottom + left < body)) && body=$((bottom + left))
fi

h=$((bar + body))
cw=$((w + 2 * pad_x)) ch=$((h + pad_top + pad_bottom))

magick -size "${w}x${h}" xc:black -fill white \
	-draw "roundrectangle 0,0,$((w - 1)),$((h - 1)),$radius,$radius" "$tmp/mask.png"

# -type keeps the grey-only shadow from turning the composited output grayscale.
magick -size "${cw}x${ch}" xc:none -fill "rgba(0,0,0,$opacity)" \
	-draw "roundrectangle $pad_x,$((pad_top + offset_y)),$((pad_x + w - 1)),$((pad_top + offset_y + h - 1)),$radius,$radius" \
	-channel A -blur "0x$blur" +channel -type TrueColorAlpha "PNG32:$tmp/shadow.png"

case ${in,,} in
*.png)
	[[ -n $bg ]] && magick "$tmp/shadow.png" -background "$bg" -flatten -type TrueColorAlpha "PNG32:$tmp/shadow.png"
	magick "$in" -chop "0x$bar_gap+0+$bar" -crop "${w}x$h+0+0" +repage "$tmp/mask.png" -alpha off -compose CopyOpacity -composite "$tmp/rounded.png"
	magick "$tmp/shadow.png" "$tmp/rounded.png" -geometry "+$pad_x+$pad_top" -compose over -composite \
		-type TrueColorAlpha "PNG32:$out"
	;;
*)
	if [[ -z $bg && ${out,,} == *.webp ]]; then
		cp "$tmp/shadow.png" "$tmp/canvas.png"
	else
		magick "$tmp/shadow.png" -background "${bg:-white}" -flatten -type TrueColor "PNG24:$tmp/canvas.png"
	fi
	# The still canvas and mask repeat their only frame for the whole input.
	inputs=(-i "$tmp/canvas.png" -i "$in" -i "$tmp/mask.png")
	overlay="[1:v]tpad=stop_mode=clone:stop_duration=$hold,split[a][b];[a]crop=iw:$bar:0:0[t];[b]crop=iw:$body:0:${body_y}[r];[t][r]vstack,format=rgba[v];[2:v]format=gray[m];[v][m]alphamerge[w];[0:v][w]overlay=$pad_x:$pad_top"
	case ${out,,} in
	*.gif)
		# One global palette with dithering; per-frame palettes band the shadow.
		ffmpeg -loglevel error -y "${inputs[@]}" \
			-filter_complex "$overlay,palettegen=stats_mode=full" "$tmp/palette.png"
		ffmpeg -loglevel error -y "${inputs[@]}" -i "$tmp/palette.png" \
			-filter_complex "${overlay}[o];[o][3:v]paletteuse=dither=sierra2_4a" "$out"
		;;
	*.webp)
		ffmpeg -loglevel error -y "${inputs[@]}" -filter_complex "$overlay,format=yuva420p" \
			-c:v libwebp_anim -quality 90 -loop 0 "$out"
		;;
	*)
		ffmpeg -loglevel error -y "${inputs[@]}" -filter_complex "$overlay,format=yuv420p" "$out"
		;;
	esac
	;;
esac
