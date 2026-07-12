#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# nb30 — Void Linux auf dem Samsung NB30: tmux als Arbeitsplatz.
#
# Kein Fenstermanager. X traegt genau EIN Terminal (st, bildschirmfuellend),
# und darin laeuft tmux. Die Fensterverwaltung macht tmux — dafuer gibt es
# hier eine echte Schrift (JetBrains Mono) und Truecolor, was die nackte
# Textkonsole beides nicht kann.
#
# Aufruf auf dem NB30 (nach `git clone`):
#     ./install.sh
#
# Andere Schriftgroesse in st:  ST_PIXELSIZE=17 ./install.sh
# ---------------------------------------------------------------------------
set -euo pipefail

ST_VER="0.9.3"
ST_SHA="9ed9feabcded713d4ded38c8cebf36a3b08f0042ef7934a0e2b2409da56e649b"
ST_PIXELSIZE="${ST_PIXELSIZE:-15}"

HERE="$(cd "$(dirname "$0")" && pwd)"
WORK="${TMPDIR:-/tmp}/nb30-build"
mkdir -p "$WORK"

msg(){ printf '\033[1;36m>>> %s\033[0m\n' "$*"; }

command -v xbps-install >/dev/null 2>&1 || {
	echo "Kein xbps gefunden — dieses Repo ist fuer Void Linux." >&2
	exit 1
}

# --- 1. Pakete ------------------------------------------------------------
# Build-Header fuer st (das einzige, was aus Quelle gebaut wird).
# X-Laufzeit: jede dieser Zeilen war beim alten Setup ein realer Abbruch —
#   xauth               -> sonst bricht startx sofort ab ("xauth: not found")
#   xf86-video-intel    -> GMA 3150; ohne DDX findet Xorg keinen Screen
#   mesa-dri            -> swrast-Fallback (HW-GL gibt es auf GMA3150 nicht)
#   xf86-input-libinput -> sonst laeuft X ohne Tastatur und Maus
#   dejavu/liberation   -> fontconfig braucht einen skalierbaren Fallback
#   setxkbmap           -> das de-Layout im X (.xinitrc ruft es auf)
msg "Pakete installieren"
sudo xbps-install -Sy \
	tmux git kbd terminus-font w3m curl \
	base-devel libX11-devel libXft-devel fontconfig-devel freetype-devel \
	xorg-server xinit xauth setxkbmap xset \
	xf86-video-intel mesa-dri xf86-input-libinput \
	dejavu-fonts-ttf liberation-fonts-ttf

msg "Browser (luakit als Alltag, firefox-esr als Notnagel)"
for p in luakit firefox-esr; do
	sudo xbps-install -y "$p" >/dev/null 2>&1 \
		|| msg "  Warnung: '$p' nicht installierbar — 'browser' faellt auf den naechsten zurueck"
done

# --- 2. JetBrains Mono ----------------------------------------------------
# In Void nicht paketiert. Fehlt sie, faellt fontconfig still auf irgendeinen
# monospace zurueck — st startet, sieht aber anders aus als gedacht.
if ! fc-list 2>/dev/null | grep -qi "JetBrains Mono"; then
	msg "JetBrains Mono laden -> /usr/local/share/fonts"
	JBDIR="/usr/local/share/fonts/jetbrains-mono"
	JBBASE="https://github.com/JetBrains/JetBrainsMono/raw/master/fonts/ttf"
	for s in Regular Medium Bold; do
		if curl -fsSL "$JBBASE/JetBrainsMono-$s.ttf" -o "$WORK/JetBrainsMono-$s.ttf"; then
			sudo install -Dm644 "$WORK/JetBrainsMono-$s.ttf" "$JBDIR/JetBrainsMono-$s.ttf"
		else
			msg "  Warnung: JetBrainsMono-$s.ttf nicht ladbar (Netz?) — uebersprungen"
		fi
	done
	sudo fc-cache -f >/dev/null 2>&1 || true
fi

# --- 3. st bauen ----------------------------------------------------------
# Das einzige Kompilat. st-config.h traegt Nord + JetBrains Mono.
msg "st $ST_VER laden + Pruefsumme verifizieren"
STTGZ="$WORK/st-$ST_VER.tar.gz"
[ -f "$STTGZ" ] || curl -fsSL -o "$STTGZ" "https://dl.suckless.org/st/st-$ST_VER.tar.gz"
echo "$ST_SHA  $STTGZ" | sha256sum -c - >/dev/null || {
	echo "PRUEFSUMME FALSCH — Abbruch." >&2
	exit 1
}

msg "st bauen (Schriftgroesse $ST_PIXELSIZE)"
rm -rf "$WORK/st-$ST_VER"
tar xzf "$STTGZ" -C "$WORK"
sed "s/pixelsize=15/pixelsize=$ST_PIXELSIZE/" "$HERE/st-config.h" > "$WORK/st-$ST_VER/config.h"
make -C "$WORK/st-$ST_VER" clean >/dev/null
make -C "$WORK/st-$ST_VER" >/dev/null
sudo make -C "$WORK/st-$ST_VER" install >/dev/null

# --- 4. Textkonsole: Font + Keymap ---------------------------------------
# Die TTY siehst du nur noch beim Einloggen — trotzdem lesbar halten.
#
# KEIN Theming der Palette. Die Linux-Konsole kann nur 16 Farben, und die
# Kernel-Palette bringt den GMA3150-Framebuffer zum Glitchen (rosa/schwarze
# Sprenkel). Real passiert, 12.7.2026. Finger weg.
#
# KEYMAP ist dagegen Pflicht: ohne X gibt es niemanden, der 'setxkbmap de'
# aufruft. Sonst bleibt die TTY auf US-QWERTY und die Tilde (AltGr+Plus)
# trifft ins Leere. 'nodeadkeys', damit ~ ^ ` direkt kommen.
setkv(){ # datei schluessel wert — idempotent
	if sudo grep -q "^$2=" "$1" 2>/dev/null; then
		sudo sed -i "s|^$2=.*|$2=$3|" "$1"
	else
		echo "$2=$3" | sudo tee -a "$1" >/dev/null
	fi
}

msg "Konsolen-Font + Tastaturlayout (runit liest /etc/rc.conf)"
setkv /etc/rc.conf FONT   '"ter-116b"'
setkv /etc/rc.conf KEYMAP '"de-latin1-nodeadkeys"'
sudo setfont ter-116b 2>/dev/null || true
sudo loadkeys de-latin1-nodeadkeys 2>/dev/null || true

# --- 5. tmux + .xinitrc ---------------------------------------------------
msg "~/.tmux.conf und ~/.xinitrc verlinken"
for F in .tmux.conf; do
	if [ -e "$HOME/$F" ] && [ ! -L "$HOME/$F" ]; then
		mv "$HOME/$F" "$HOME/$F.bak.$(date +%Y%m%d%H%M%S)"
		msg "  bestehende ~/$F gesichert"
	fi
	ln -sf "$HERE/$F" "$HOME/$F"
done
if [ -e "$HOME/.xinitrc" ] && [ ! -L "$HOME/.xinitrc" ]; then
	mv "$HOME/.xinitrc" "$HOME/.xinitrc.bak.$(date +%Y%m%d%H%M%S)"
	msg "  bestehende ~/.xinitrc gesichert"
fi
ln -sf "$HERE/xinitrc" "$HOME/.xinitrc"

TPM="$HOME/.tmux/plugins/tpm"
if [ ! -d "$TPM" ]; then
	msg "TPM holen (resurrect/continuum — Sessions ueberstehen einen Reboot)"
	git clone --depth 1 https://github.com/tmux-plugins/tpm "$TPM"
fi

# --- 6. Skripte nach ~/.local/bin ----------------------------------------
msg "browser + tmux-hilfe -> ~/.local/bin"
mkdir -p "$HOME/.local/bin"
for TOOL in browser tmux-hilfe; do
	chmod +x "$HERE/bin/$TOOL"
	ln -sf "$HERE/bin/$TOOL" "$HOME/.local/bin/$TOOL"
done

# --- 7. Automatisch starten beim Login auf tty1 ---------------------------
# Bewusst OHNE 'exec': scheitert X, landet man in der Shell statt sich
# auszusperren. Zum Abschalten die Zeile in ~/.bash_profile auskommentieren.
PROFILE="$HOME/.bash_profile"
touch "$PROFILE"
LINE='[ "$(tty)" = "/dev/tty1" ] && [ -z "$DISPLAY" ] && startx'
if ! grep -qF 'startx' "$PROFILE" 2>/dev/null; then
	msg "startx beim Login auf tty1 (in ~/.bash_profile)"
	{ echo ''; echo '# nb30: auf tty1 direkt in st/tmux starten. Zum Abschalten auskommentieren.'; echo "$LINE"; } >> "$PROFILE"
fi
# ~/.local/bin in den PATH, falls noch nicht drin
if ! grep -q '.local/bin' "$PROFILE" 2>/dev/null; then
	{ echo ''; echo 'export PATH="$HOME/.local/bin:$PATH"'; } >> "$PROFILE"
fi

# --- 8. Selbstpruefung ----------------------------------------------------
# Die Lehre aus acht stillen Luecken: fehlt ein Binary, scheitert der Aufruf
# lautlos und man sucht tagelang. Also einmal ehrlich nachsehen.
echo
msg "Selbstpruefung — ist alles da, was dieses Setup aufruft?"
FEHLT=""
check(){
	if command -v "$1" >/dev/null 2>&1; then
		printf '  \033[32m✓\033[0m %-12s %s\n' "$1" "$2"
	else
		printf '  \033[31m✗\033[0m %-12s %s\n' "$1" "$2"
		FEHLT="$FEHLT $1"
	fi
}
check tmux       "der Arbeitsplatz"
check st         "das Terminal (gerade gebaut)"
check startx     "startet X mit st"
check setxkbmap  "de-Layout im X — .xinitrc ruft es auf"
check xset       "Bildschirm-Blanking abschalten"
check loadkeys   "de-Layout im TTY"
check w3m        "Nachschlagen ohne X"
check luakit     "Browser (oder firefox-esr)"

if ! fc-list 2>/dev/null | grep -qi "JetBrains Mono"; then
	printf '  \033[31m✗\033[0m %-12s %s\n' "JetBrains" "Schrift fehlt — st nimmt einen Fallback"
fi

if [ -n "$FEHLT" ]; then
	echo
	msg "Es fehlt:$FEHLT"
	echo "    sudo xbps-install -y$FEHLT"
fi

echo
msg "Fertig."
echo "  - Neu einloggen -> startet von selbst in st + tmux."
echo "  - Von Hand:      startx"
echo "  - Plugins holen: Strg+B, dann grosses I"
echo "  - Spickzettel:   tmux-hilfe"
echo "  - Schrift zu klein/gross:  ST_PIXELSIZE=17 ./install.sh"
