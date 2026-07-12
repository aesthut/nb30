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
#   dbus                -> DIE stille Luecke Nr. 9 (12.7.2026): luakit UND
#                          firefox sind gegen libdbus gelinkt und beenden sich
#                          ohne laufenden Session-Bus SOFORT und OHNE Meldung.
#                          Im Xorg-Log steht dann nur "Server terminated
#                          successfully" — man sucht sich tot. Beim alten Setup
#                          kam dbus als Beifang mit NetworkManager mit; ohne den
#                          fiel es unter den Tisch. 'browser' startet den Bus per
#                          dbus-run-session nur fuer die Laufzeit des Browsers,
#                          es laeuft also KEIN Dauerdienst.
#   dejavu/liberation   -> SKALIERBARE Schriften. Ohne sie hat das System NULL
#                          Fonts: terminus ist ein Bitmap-Font, den fontconfig
#                          weder als sans-serif noch als monospace aufloest.
#                          Firefox zeigt dann eine Seite ganz ohne Text an.
#                          (Stand schon in der alten Notiz als Fallstrick Nr. 4 —
#                          und ich habe die Grube beim schlanken Repo wieder
#                          aufgemacht. 12.7.2026.)
msg "Pakete installieren"
sudo xbps-install -Sy \
	tmux git kbd terminus-font w3m curl dbus fzf \
	xorg-server xinit xauth setxkbmap \
	xf86-video-intel mesa-dri xf86-input-libinput \
	dejavu-fonts-ttf liberation-fonts-ttf

# Browser: FIREFOX, nicht luakit. Am 12.7.2026 durchgetestet: luakit (WebKitGTK)
# braucht auf der GMA 3150 zwingend Software-Rendering und ist damit auf einem
# 1,66-GHz-Atom unbrauchbar zaeh — selbst auf einer reinen Textseite. Firefox
# kommt mit dem Chip allein zurecht und laeuft fluessig.
# xdotool zieht das Fenster auf volle Groesse: ohne Fenstermanager tut das sonst
# niemand, und Firefox laesst auf 1024x600 sonst viel Platz liegen.
# Nicht abbruchhart: fehlt eines, bleibt nur der zugehoerige Weg zu.
msg "Browser (firefox — auf dieser Kiste der einzige brauchbare)"
for p in firefox xdotool; do
	sudo xbps-install -y "$p" >/dev/null 2>&1 \
		|| msg "  Warnung: '$p' nicht installierbar — 'browser' faellt auf den naechsten zurueck"
done

# --- 1a. Die Arbeitsumgebung ----------------------------------------------
# Ohne die ist tmux ein leerer Schreibtisch. Am 12.7.2026 fiel auf, dass auf
# dem NB30 nicht einmal 'nano' lag — man konnte auf dem Geraet keine einzige
# Datei bearbeiten.
#
#   micro    Editor. Bedient sich wie ein normaler: Strg+S, Strg+Q, Maus.
#            Kein Vim-Lernen noetig — es wird schon tmux gelernt.
#   ranger   Dateimanager. ZIEHT PYTHON NACH (23 MB) und startet dadurch auf
#            einem Atom spuerbar traeger als ein Go-Programm. Bewusst gewaehlt:
#            bessere Vorschau, und Roland kennt die Bedienung. Fuehlt es sich
#            zaeh an, ist 'lf' der Ersatz (gleiches Konzept, ohne Python).
#   htop     Prozesse. 407 KB. (btop sieht besser aus, malt aber staendig neu.)
#   eza/bat  ls und cat mit Farben — der sichtbarste Komfortgewinn.
#   ripgrep  Suche, die auch auf dieser Kiste schnell ist.
#   zoxide   'z projekt' springt dorthin, wo man oft war.
#   starship Prompt mit Git-Zustand und Powerline-Pfeilen (der Font kann sie).
#   bash-completion  Tab-Vervollstaendigung. Fehlte komplett.
#
# BEWUSST NICHT: helix (207 MB), yazi (23 MB), btop — alle drei schoen, alle
# drei zu hungrig fuer diese Hardware.
msg "Arbeitsumgebung (Editor, Dateimanager, Werkzeuge)"
sudo xbps-install -y \
	micro ranger htop ncdu tree \
	eza bat ripgrep fd \
	zoxide starship \
	bash-completion \
	|| msg "  Warnung: nicht alle Werkzeuge installierbar"

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

# FONT: TamzenForPowerline10x20 — am Geraet ausgesucht. Weicher gezeichnet als
# Terminus, und die Powerline-Variante bringt Pfeil- und Blockzeichen mit.
# Kein Void-Paket: 'tty-font --holen' laedt ihn, darum laeuft das HIER, bevor
# der Font in rc.conf eingetragen wird. Sonst staende dort ein Font, den es auf
# der Platte nicht gibt — und der Boot fiele stumm auf den Standard zurueck.
# Andere waehlen:  FONT_NAME=ter-118b ./install.sh
FONT_NAME="${FONT_NAME:-TamzenForPowerline10x20}"

msg "Konsolenschriften holen (Tamzen, Spleen)"
chmod +x "$HERE/bin/tty-font"   # wird weiter unten nochmal gesetzt, aber hier schon gebraucht
"$HERE/bin/tty-font" --holen || msg "  Warnung: Schriften nicht ladbar (Netz?)"

# Traegt sich der gewuenschte Font wirklich? Wenn nicht, auf Terminus zurueck —
# lieber eine haessliche Konsole als eine, die nach dem Reboot nicht lesbar ist.
if ! sudo setfont "$FONT_NAME" 2>/dev/null; then
	msg "  '$FONT_NAME' nicht ladbar — falle auf ter-118b zurueck"
	FONT_NAME="ter-118b"
	sudo setfont "$FONT_NAME" 2>/dev/null || true
fi

msg "Konsolen-Font ($FONT_NAME) + Tastaturlayout (runit liest /etc/rc.conf)"
setkv /etc/rc.conf FONT   "\"$FONT_NAME\""
setkv /etc/rc.conf KEYMAP '"de-latin1-nodeadkeys"'
sudo loadkeys de-latin1-nodeadkeys 2>/dev/null || true

# --- 2a. Shell einrichten -------------------------------------------------
# Hier steckt mehr Komfort als in der halben tmux-Plugin-Liste: Strg+R
# durchsucht die ganze Befehlshistorie, Tab vervollstaendigt endlich Optionen
# und git-Branches, ls und cat zeigen Farben.
msg "~/.bashrc und Prompt einrichten"
if [ -e "$HOME/.bashrc" ] && [ ! -L "$HOME/.bashrc" ]; then
	mv "$HOME/.bashrc" "$HOME/.bashrc.bak.$(date +%Y%m%d%H%M%S)"
	msg "  bestehende ~/.bashrc gesichert"
fi
ln -sf "$HERE/bashrc" "$HOME/.bashrc"

mkdir -p "$HOME/.config"
ln -sf "$HERE/starship.toml" "$HOME/.config/starship.toml"

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
	msg "TPM holen (der tmux Plugin Manager)"
	git clone --depth 1 https://github.com/tmux-plugins/tpm "$TPM"
fi

# Plugins gleich mitinstallieren, statt den Nutzer 'Strg+B, dann I' tippen zu
# lassen. install_plugins braucht einen laufenden Server — also einen wegwerf-
# baren starten.
msg "tmux-Plugins holen (sensible, resurrect, continuum, prefix-highlight)"
tmux new-session -d -s _setup 2>/dev/null || true
"$TPM/bin/install_plugins" >/dev/null 2>&1 || msg "  Warnung: Plugins nicht ladbar (Netz?) — spaeter: Strg+B, dann I"
tmux kill-session -t _setup 2>/dev/null || true

# --- 4. Skripte nach ~/.local/bin ----------------------------------------
msg "eigene Skripte -> ~/.local/bin"
mkdir -p "$HOME/.local/bin"
for TOOL in browser tmux-hilfe tty-font tmux-status; do
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
check firefox    "Browser — auf dieser Kiste der einzige brauchbare"
check xdotool    "zieht das Browserfenster auf den ganzen Schirm (kein WM da)"
check git        "Repos"
check dbus-run-session "Session-Bus fuer den Browser — ohne das startet KEINER"
check fzf        "Suchliste in tmux (Strg+B, dann F) + Strg+R in der Shell"
check micro      "Editor — ohne den kann man auf dem Geraet nichts bearbeiten"
check ranger     "Dateimanager"
check htop       "Prozesse"
check eza        "ls mit Farben"
check bat        "cat mit Syntaxfarben"
check starship   "Prompt"

# Schriften: kein Binary, also von Hand pruefen. Ohne skalierbare Fonts zeigt
# Firefox eine Seite komplett ohne Text.
if [ "$(fc-list 2>/dev/null | wc -l)" -gt 0 ]; then
	printf '  \033[32m✓\033[0m %-14s %s\n' "Schriften" "$(fc-list 2>/dev/null | wc -l) gefunden"
else
	printf '  \033[31m✗\033[0m %-14s %s\n' "Schriften" "KEINE — Firefox zeigt keinen Text an"
	echo "      sudo xbps-install -y dejavu-fonts-ttf liberation-fonts-ttf"
fi

if [ -n "$FEHLT" ]; then
	echo
	msg "Es fehlt:$FEHLT"
	echo "    sudo xbps-install -y$FEHLT"
fi

# Eigene Skripte SEPARAT pruefen — und zwar ob die DATEI liegt, nicht ob sie
# im PATH auffindbar ist. Der PATH-Eintrag greift erst beim naechsten Login,
# in diesem Lauf also noch nicht. Sonst meldet die Pruefung sie faelschlich
# als fehlend und schlaegt 'xbps-install browser tmux-hilfe' vor — Pakete,
# die es nicht gibt.
echo
msg "Eigene Skripte"
for T in browser tmux-hilfe tty-font tmux-status; do
	if [ -x "$HOME/.local/bin/$T" ]; then
		printf '  \033[32m✓\033[0m %-14s %s\n' "$T" "liegt in ~/.local/bin"
	else
		printf '  \033[31m✗\033[0m %-14s %s\n' "$T" "NICHT verlinkt — install.sh nochmal laufen lassen"
	fi
done
if ! command -v tmux-hilfe >/dev/null 2>&1; then
	echo
	msg "~/.local/bin ist in DIESER Shell noch nicht im PATH."
	echo "    source ~/.bash_profile      # jetzt sofort"
	echo "    (ab dem naechsten Login von selbst)"
fi

echo
msg "Fertig."
echo "  - tmux starten:      tmux"
echo "  - Plugins holen:     Strg+B, dann grosses I"
echo "  - Spickzettel:       tmux-hilfe"
echo "  - alles, was rechnet: ssh vps   (Claude Code laeuft auf dem N450 nicht)"
echo "  - Webseite:          w3m URL   oder   browser URL"
