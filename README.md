# Nterm

Terminal flotante para Neovim, con una barra lateral para moverte entre varios terminales.

![Demo](assets/demo.gif)

## Capturas

| Terminal | Barra lateral | Aviso antes de cerrar |
|---|---|---|
| ![Terminal](assets/terminal.png) | ![Barra lateral](assets/sidebar.png) | ![Confirmación](assets/confirm.png) |

## Requisitos

- Neovim 0.11 o superior.

## Instalación

No hace falta llamar a `setup()`: el plugin se activa solo al arrancar Neovim.

### lazy.nvim

```lua
{ 'Gogiu23/Nterm' }
```

### vim.pack (Neovim 0.12+)

```lua
vim.pack.add({ 'https://github.com/Gogiu23/Nterm' })
```

### packer.nvim

```lua
use 'Gogiu23/Nterm'
```

### Sin gestor de plugins

```sh
git clone https://github.com/Gogiu23/Nterm \
  ~/.local/share/nvim/site/pack/plugins/start/nterm
```

Reinicia Neovim y pulsa `Ctrl-/`. Para comprobar que se ha cargado: `:lua print(vim.g.loaded_nterm)` debe mostrar `true`.

## Uso

| Dónde | Tecla | Acción |
|---|---|---|
| En cualquier sitio | `Ctrl-/` | Abre u oculta el terminal (si no hay ninguno, crea uno) |
| Terminal | `Esc Esc` | Pasa a modo normal |
| Terminal, modo normal | `Space` | Abre la barra lateral |
| Barra | `1`–`9` / `Enter` | Cambia a ese terminal y cierra la barra |
| Barra | `Ctrl-+` | Abre un terminal nuevo y cierra la barra |
| Barra | `Ctrl-d` | Cierra el terminal seleccionado (pide confirmación) |
| Barra | `Space` / `q` / `Esc` | Cierra la barra y vuelve al terminal |

La barra muestra el último comando ejecutado en cada terminal.

## Guía

Dentro de Neovim:

```vim
:NtermHelp
```

o, si prefieres la ayuda estándar, `:help nterm`.

## Notas

- `Ctrl-+` solo llega a Neovim en terminales con el protocolo de teclado de kitty (Kitty, WezTerm, Ghostty). En el resto usa `Ctrl-=` o `+`.
- Muchas terminales envían `Ctrl-/` como `Ctrl-_`; Nterm mapea los dos.
- El último comando se obtiene de la línea del prompt, cortando por el primer `$ > # % ❯`. Con prompts poco habituales puede mostrarse la línea entera.

## Desarrollo

```sh
# prueba rápida sin interfaz
nvim --headless -u NONE --cmd 'set rtp+=.' -l tests/smoke.lua

# regenerar las capturas (requiere vhs)
vhs assets/demo.tape
```
