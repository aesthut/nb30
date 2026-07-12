#!/bin/sh
# ~/.xinitrc — nb30
#
# Kein Fenstermanager. X existiert nur, um EIN Terminal zu tragen:
# st, bildschirmfuellend, und darin tmux. Die Fensterverwaltung macht tmux.
#
# Schliesst du tmux (letztes Fenster weg), endet st, endet X, und du landest
# wieder in der Textkonsole.

# de-Layout im X. Ohne WM ruft das sonst niemand auf.
setxkbmap de 2>/dev/null

# Bildschirm nicht abdunkeln/blanken waehrend der Arbeit
xset s off -dpms 2>/dev/null

# GMA 3150 hat kein Hardware-GL — Software-Rendering, sonst Absturz.
export LIBGL_ALWAYS_SOFTWARE=1

# st startet tmux direkt. 'attach || new' haengt sich an eine laufende Session,
# statt bei jedem startx eine neue anzulegen.
exec st -e sh -c 'tmux attach || tmux new'
