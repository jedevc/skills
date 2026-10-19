# Regenerate from this directory:
#   ../render.sh example.tape
#   ../frame.sh example.gif example-framed.gif --bg '#eef3fb'
#   rm example.gif example.png example-last.png
Output example.gif
Set Width 1400
Set Height 900
Set WaitTimeout 120s
Source "../style.tape"

Hide
Type@1ms "d=$(mktemp -d) && cp ../style.tape ../frame.sh ../render.sh $d && cd $d" Enter
Type@1ms `printf '%s\n' 'Output demo.gif' 'Source "style.tape"' '' 'Type "echo hello, world" Enter' 'Wait' 'Screenshot demo.png' >demo.tape && clear` Enter
Wait
Show

Type "# record a real terminal session with vhs, then frame it" Enter
Wait
Type "cat demo.tape" Enter
Wait
Type "./render.sh demo.tape" Enter
# Skip the dead air while the nested recording runs.
Hide
Wait
Show
Type "ls demo*" Enter
Wait
Screenshot example.png
