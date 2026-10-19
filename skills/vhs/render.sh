#!/usr/bin/env bash
# Record a tape with VHS, frame every Output and Screenshot it writes, and
# grab the last frame of each framed screencast for checking.
#
# Usage: render.sh <tape> [--format webp|gif|mp4|webm] [--bg <color>]
#
# Runs from the tape's directory, so the recorded shell starts there and
# relative paths in the tape resolve against it. For each raw <name>.<ext>
# it writes <name>-framed.png (screenshots) or <name>-framed.<format>
# (screencasts, default webp) plus <name>-last.png. Screencasts pause for 1s
# after each visible Wait, so viewers can read the output.
set -euo pipefail

usage() { sed -n '2,11p' "$0" | sed 's/^# \{0,1\}//'; exit 2; }

[[ $# -ge 1 ]] || usage
tape=$1
shift
format=webp frame_args=()
while [[ $# -gt 0 ]]; do
	case $1 in
	--format) format=$2; shift 2 ;;
	--bg) frame_args+=(--bg "$2"); shift 2 ;;
	*) usage ;;
	esac
done

skill=$(cd "$(dirname "$(readlink -f "$0")")" && pwd)
dir=$(dirname "$tape")
cd "$dir"
tape=$(basename "$tape")

paths() { sed -n "s/^$1[[:space:]]\{1,\}\"\{0,1\}\([^\"]*\)\"\{0,1\}[[:space:]]*$/\1/p" "$tape"; }
mapfile -t casts < <(paths Output)
mapfile -t shots < <(paths Screenshot)

framed=()
for f in "${shots[@]}"; do framed+=("${f%.*}-framed.png"); done
for f in "${casts[@]}"; do framed+=("${f%.*}-framed.$format" "${f%.*}-last.png"); done
rm -f -- "${casts[@]}" "${shots[@]}" "${framed[@]}"

tmp=$(mktemp --suffix=.tape)
trap 'rm -f "$tmp"' EXIT
# Wait matches the prompt before it's painted, and VHS drops a Screenshot
# that is the tape's last command.
awk -v pause=$((${#casts[@]} > 0)) '
	/^Hide/ { hidden = 1 }
	/^Show/ { hidden = 0 }
	/^Screenshot[[:space:]]/ { print "Sleep 100ms" }
	{ print }
	/^Wait/ && pause && !hidden { print "Sleep 1s" }
	END { print "Sleep 200ms" }
' "$tape" >"$tmp"
vhs -q "$tmp"

for f in "${shots[@]}"; do
	"$skill/frame.sh" "$f" "${f%.*}-framed.png" "${frame_args[@]}"
done
for f in "${casts[@]}"; do
	out=${f%.*}-framed.$format
	"$skill/frame.sh" "$f" "$out" "${frame_args[@]}"
	case $format in
	webp | gif) magick "$out" -coalesce -delete 0--2 "${f%.*}-last.png" ;;
	*) ffmpeg -loglevel error -y -sseof -0.3 -i "$out" -frames:v 1 "${f%.*}-last.png" ;;
	esac
done

printf '%s\n' "${framed[@]/#/$dir/}"
