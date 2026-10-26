# Regenera los pantallazos del README: vhs assets/demo.tape (desde la raíz del repo)
Output assets/demo.gif

Set Shell "bash"
Set FontSize 16
Set Width 1300
Set Height 760
Set Padding 16
Set Theme "TokyoNight"
Set TypingSpeed 40ms
Env PS1 "$ "

Hide
Type "nvim -u NONE --cmd 'set rtp+=. termguicolors' -c 'runtime plugin/nterm.lua' -c 'set shell=bash\ --norc\ --noprofile'"
Enter
Sleep 1.5s
Type ":lua require('nterm').toggle()"
Enter
Sleep 1.5s
Show

Type "ls" Enter Sleep 500ms
Type "echo 'hola desde Nterm'" Enter Sleep 1s
Screenshot assets/terminal.png

# segundo terminal
Escape Sleep 150ms Escape Sleep 300ms
Space Sleep 500ms
Type "+" Sleep 1.5s
Type "nvim --version | head -1" Enter Sleep 1s

# tercero
Escape Sleep 150ms Escape Sleep 300ms
Space Sleep 500ms
Type "+" Sleep 1.5s
Type "ls lua/nterm" Enter Sleep 1s

# barra lateral con los tres
Escape Sleep 150ms Escape Sleep 300ms
Space Sleep 1s
Screenshot assets/sidebar.png
Sleep 1s

# aviso antes de cerrar
Ctrl+D Sleep 1s
Screenshot assets/confirm.png
Sleep 1s
Type "n" Sleep 500ms

# cambiar al 1
Type "1" Sleep 1.5s
