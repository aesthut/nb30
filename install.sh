#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# nb30 — Void Linux auf dem Samsung NB30: TTY + tmux als Arbeitsplatz.
#
# Kein Fenstermanager, kein Compile, kein Theming der Textkonsole.
# X wird nur gestartet, wenn ein Browser gebraucht wird ('browser' macht das
# selbst, als Einzelanwendung ohne WM).
#
# Aufruf auf dem NB30 (nach `git clone`):
#     ./install.sh
# ---------------------------------------------------------------------------
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
msg(){ printf '\033[1;36m>>> %s\033[0m\n' "$*"; }

# --- 0. Distro pruefen ----------------------------------------------------
command -v xbps-install >/dev/null 2>&1 || {
	echo "Kein xbps gefunden — dieses Repo ist fuer Void Linux." >&2
	exit 1
}

# --- 1. Pakete ------------------------------------------------------------
# Basis: das, was den Arbeitsplatz ausmacht.
#   tmux           der Arbeitsplatz selbst
#   kbd            loadkeys + setfont (Keymap und Konsolenfont)
#   terminus-font  gut lesbar auf 1024x600
#   w3m            Nachschlagen ohne X — der schnellste Weg auf dieser Kiste
#
# X nur fuer den Browser. Jede dieser Zeilen war beim alten Setup ein realer
# Abbruch (siehe Vault-Notiz, "Offene Punkte") — sie gelten weiter, weil
# 'browser' echtes X startet:
#   xauth               -> sonst bricht startx sofort ab ("xauth: not found")
#   xf86-video-intel    -> GMA 3150; ohne DDX findet Xorg keinen Screen
#   mesa-dri            -> swrast-Fallback (HW-GL gibt es auf GMA3150 nicht)
#   xf86-input-libinput -> sonst laeuft X ohne Tastatur und Maus
#   setxkbmap           -> 'browser' setzt damit das de-Layout im X
msg "Pakete installieren"
sudo xbps-install -Sy \
	tmux git kbd terminus-font w3m curl \
	xorg-server xinit xauth setxkbmap \
	xf86-video-intel mesa-dri xf86-input-libinput

# Browser: nicht abbruchhart. Fehlt einer, bleibt nur der zugehoerige Weg zu.
msg "Browser (luakit als Alltag, firefox-esr als Notnagel)"
for p in luakit firefox-esr; do
	sudo xbps-install -y "$p" >/dev/null 2>&1 \
		|| msg "  Warnung: '$p' nicht installierbar — 'browser' faellt auf den naechsten zurueck"
done

# --- 2. Textkonsole: Font + Keymap ---------------------------------------
# Bewusst KEIN Theming der Palette. Zwei Gruende:
#   1. Die Linux-Konsole kann nur 16 Farben — Nord ginge nur ueber die
#      Kernel-Palette, und die bringt den GMA3150-Framebuffer zum Glitchen
#      (rosa/schwarze Sprenkel). Real passiert, 12.7.2026.
#   2. Es braucht sie nicht. Schwarzer Grund, Terminus, fertig.
#
# KEYMAP ist dagegen Pflicht: es gibt kein X, das 'setxkbmap de' setzen koennte.
# Ohne KEYMAP bleibt die TTY auf US-QWERTY und die Tilde (AltGr+Plus) trifft
# ins Leere. 'nodeadkeys', damit ~ ^ ` direkt kommen statt als Tottasten.
setkv(){ # datei schluessel wert — idempotent
	if sudo grep -q "^$2=" "$1" 2>/dev/null; then
		sudo sed -i "s|^$2=.*|$2=$3|" "$1"
	else
		echo "$2=$3" | sudo tee -a "$1" >/dev/null
	fi
}

# FONT: ter-118b — 9x18, fett. Am Geraet als passend befunden (ter-116n war zu
# klein und zu duenn, ter-124b zu gross). Andere Schriften zum Durchprobieren
# holt 'tty-font' (Tamzen, Spleen) — siehe bin/tty-font.
# Anders waehlen:  FONT_NAME=Tamzen10x20 ./install.sh   (Tamzen hat kein Fett)
FONT_NAME="${FONT_NAME:-ter-118b}"

msg "Konsolen-Font ($FONT_NAME) + Tastaturlayout (runit liest /etc/rc.conf)"
setkv /etc/rc.conf FONT   "\"$FONT_NAME\""
setkv /etc/rc.conf KEYMAP '"de-latin1-nodeadkeys"'

# sofort anwenden, damit man nicht erst neu booten muss
sudo setfont "$FONT_NAME" 2>/dev/null || true
sudo loadkeys de-latin1-nodeadkeys 2>/dev/null || true

# --- 3. tmux --------------------------------------------------------------
msg "~/.tmux.conf verlinken"
if [ -e "$HOME/.tmux.conf" ] && [ ! -L "$HOME/.tmux.conf" ]; then
	BAK="$HOME/.tmux.conf.bak.$(date +%Y%m%d%H%M%S)"
	mv "$HOME/.tmux.conf" "$BAK"
	msg "  bestehende ~/.tmux.conf gesichert -> $BAK"
fi
ln -sf "$HERE/.tmux.conf" "$HOME/.tmux.conf"

TPM="$HOME/.tmux/plugins/tpm"
if [ ! -d "$TPM" ]; then
	msg "TPM holen (resurrect/continuum — Sessions ueberstehen einen Reboot)"
	git clone --depth 1 https://github.com/tmux-plugins/tpm "$TPM"
fi

# --- 4. Skripte nach ~/.local/bin ----------------------------------------
msg "browser + tmux-hilfe -> ~/.local/bin"
mkdir -p "$HOME/.local/bin"
for TOOL in browser tmux-hilfe tty-font; do
	chmod +x "$HERE/bin/$TOOL"
	ln -sf "$HERE/bin/$TOOL" "$HOME/.local/bin/$TOOL"
done
# ~/.local/bin in den PATH — sonst sind browser/tmux-hilfe/tty-font zwar da,
# aber nicht aufrufbar ("command not found"). Frueher stand hier nur ein
# Hinweis; der half niemandem.
PROFILE="$HOME/.bash_profile"
touch "$PROFILE"
if ! grep -q 'HOME/.local/bin' "$PROFILE" 2>/dev/null; then
	msg "~/.local/bin in den PATH (in ~/.bash_profile)"
	{ echo ''; echo '# nb30: eigene Skripte (browser, tmux-hilfe, tty-font)'
	  echo 'export PATH="$HOME/.local/bin:$PATH"'; } >> "$PROFILE"
	msg "  greift beim naechsten Login. Jetzt sofort:  source ~/.bash_profile"
fi

# --- 5. Selbstpruefung ----------------------------------------------------
# Die Lehre aus acht stillen Luecken im Vorgaenger-Setup: fehlt ein Binary,
# scheitert der Aufruf lautlos ins Leere und man sucht tagelang. Also einmal
# ehrlich nachsehen und benennen, was fehlt.
echo
msg "Selbstpruefung — ist alles da, was dieses Setup aufruft?"
FEHLT=""
check(){ # binary  wofuer
	if command -v "$1" >/dev/null 2>&1; then
		printf '  \033[32m✓\033[0m %-14s %s\n' "$1" "$2"
	else
		printf '  \033[31m✗\033[0m %-14s %s\n' "$1" "$2"
		FEHLT="$FEHLT $1"
	fi
}
check tmux       "der Arbeitsplatz"
check loadkeys   "de-Layout im TTY — ohne das keine Tilde"
check setfont    "Konsolen-Font"
check startx     "X fuer den Browser"
check setxkbmap  "de-Layout im X (setzt 'browser' selbst)"
check w3m        "Nachschlagen ohne X"
check luakit     "Browser (oder firefox-esr als Rueckfall)"
check git        "Repos"
# die eigenen Skripte: liegen sie im PATH?
for T in browser tmux-hilfe tty-font; do
	check "$T" "eigenes Skript"
done

if [ -n "$FEHLT" ]; then
	echo
	msg "Es fehlt:$FEHLT"
	echo "    sudo xbps-install -y$FEHLT"
fi

echo
msg "Fertig."
echo "  - tmux starten:      tmux"
echo "  - Plugins holen:     Strg+B, dann grosses I"
echo "  - Spickzettel:       tmux-hilfe"
echo "  - alles, was rechnet: ssh vps   (Claude Code laeuft auf dem N450 nicht)"
echo "  - Webseite:          w3m URL   oder   browser URL"
