---
name: vhs
description: Produce polished terminal screenshots (PNG) and screencasts (WebP/GIF/MP4/WebM) of real CLI sessions using VHS, framed Carbon-style with rounded corners, macOS window buttons and a soft drop shadow. Use when the user asks for a terminal screenshot, a screencast/GIF/recording of a command, or an image of CLI output for slides, docs, blog posts or PRs.
---

# vhs

Record a real terminal session with VHS and frame it Carbon-style, all in one
`render.sh` call. Screenshots and screencasts share one style: `style.tape`
(VHS settings) and `frame.sh` (corners + Carbon shadow,
`0 20px 68px rgba(0,0,0,0.55)`).

Requires `vhs`, `magick` (ImageMagick 7) and `ffmpeg`.

## Workflow

1. Make sure the command actually works first: run it once non-interactively
   and check the output is what you want to show. Prefer a throwaway resource
   (instance, repo, dir) over touching the user's real ones, and clean it up
   afterwards.
2. Write a tape into its own scratch directory (never this skill dir) and
   render it, in the same shell call:

   ```sh
   mkdir -p <dir> && cat > <dir>/demo.tape <<'TAPE'
   Output demo.gif
   Set Width 1400
   Set Height 900
   Source "<skill>/style.tape"
   Env SOME_PROFILE dev

   Hide
   Type "rm -rf demo-repo && clear" Enter
   Wait
   Show

   Type "my-cli do-thing" Enter
   Wait
   Type "next command" Enter
   Wait
   Screenshot demo.png
   TAPE
   <skill>/render.sh <dir>/demo.tape
   ```

   - Write `<skill>` out as this skill's absolute path, so the heredoc can
     stay quoted and `$` in typed commands isn't expanded.
   - `Output demo.gif` is only the raw recording; `render.sh` converts it to
     WebP by default.
   - `Wait` after every command, instead of `Sleep`: it returns as soon as
     the prompt is back. In screencasts, `render.sh` adds a 1s pause after
     each visible `Wait` so viewers can read the output.
   - Over-allocate `Height`; `frame.sh` trims the empty rows below the last
     output. Only `Width` needs thought, so long lines don't wrap.
   - The recorded shell starts in the tape's directory. Reset anything the
     session creates in the `Hide` block, so re-runs start clean, and delete
     it once you're done.
   - Screenshot only? Leave out `Output`: encoding the GIF costs ~5s.
3. `render.sh` prints what it wrote: `demo-framed.png` for each `Screenshot`,
   and `demo-framed.webp` plus its last frame, `demo-last.png`, for each
   `Output`. View the framed PNG and the last frame (in parallel) before
   handing them over; there's no need to look at the raw recordings.

Prefer animated WebP for screencasts: it keeps the soft shadow over a
transparent background and is about half the size of the GIF. Browsers,
Discord and Slack all play it. If the user asks for a GIF, ask whether a WebP
would do instead before making one. For GIF and video, pass
`--format gif|mp4|webm` and set `--bg` to whatever the image will sit on
(slide background, page colour): a soft shadow can't be transparent in either.

`frame.sh <in> <out>` frames a single file if you need it directly; run it
with no arguments for its options.

See `example/`: `example.tape` records this whole workflow on a tiny demo
tape, with its framed PNG, WebP and GIF output alongside.

## VHS gotchas

- `Set Width`/`Set Height` (and any other `Set`) must come **before**
  `Source`; VHS silently ignores `Set` after it.
- The `Source` path must be quoted, or VHS fails to parse absolute paths.
- `Wait` gives up after 15s. For slower commands, `Set WaitTimeout 120s`
  before `Source`. For a TUI that never returns to the prompt, wait on its
  own output instead: `Wait+Screen /Ready/`.
- Put setup (`clear`, `cd`, env exports) inside `Hide`/`Show`; use `Env` for
  variables the recorded commands need, e.g. a CLI profile, so the visible
  command line stays clean.
- Delete stale files by name, not with a glob: zsh aborts the whole command
  when a glob matches nothing. `render.sh` already clears its own outputs.
- `render.sh` works around two VHS bugs: a `Screenshot` straight after
  `Wait` can miss the freshly printed prompt, and a `Screenshot` as the
  tape's last command is silently dropped. Run tapes through it rather than
  `vhs` directly.
