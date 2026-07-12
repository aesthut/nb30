# ~/.bashrc — nb30
#
# Die Shell ist der eigentliche Arbeitsplatz, tmux nur der Rahmen drumherum.
# Hier steckt darum mehr Komfortgewinn als in der halben tmux-Plugin-Liste —
# und das meiste davon kostet keine einzige Rechenoperation im Leerlauf.

# Nicht-interaktiv (Skripte, scp): sofort raus. Sonst bricht scp/rsync.
[[ $- != *i* ]] && return

### Werkzeuge, wenn vorhanden ----------------------------------------------
# Alles mit 'command -v' abgesichert: fehlt eines, faellt die Zeile still weg,
# statt bei jedem Login eine Fehlermeldung zu werfen.

# ls mit Farben und Symbolen. eza ist der moderne Ersatz — sieht besser aus und
# zeigt Git-Zustand. Ohne eza bleibt es beim normalen ls.
if command -v eza >/dev/null 2>&1; then
	alias ls='eza --group-directories-first'
	alias ll='eza -l --group-directories-first --git --time-style=long-iso'
	alias la='eza -la --group-directories-first --git --time-style=long-iso'
	alias lt='eza --tree --level=2 --group-directories-first'
else
	alias ls='ls --color=auto --group-directories-first'
	alias ll='ls -lh --color=auto'
	alias la='ls -lah --color=auto'
fi

# cat mit Syntaxfarben. --plain: keine Zeilennummern, kein Rahmen — sonst kann
# man die Ausgabe nicht mehr weiterverwenden.
if command -v bat >/dev/null 2>&1; then
	alias cat='bat --plain --paging=never'
	alias catn='bat --paging=never'           # mit Zeilennummern
	export MANPAGER="sh -c 'col -bx | bat -l man --plain --paging=always'"
fi

# KEIN 'alias grep=rg' und KEIN 'alias find=fd'.
# Beide verstehen die Optionen ihrer Vorbilder NICHT ('grep -E' scheitert an rg
# mit "unknown encoding"). Wer eine Anleitung aus dem Netz kopiert oder aus
# Gewohnheit tippt, landet in einer Fehlermeldung, die nichts erklaert.
# rg und fd sind schneller — aber sie heissen rg und fd.

alias df='df -h'
alias du='du -h'
alias free='free -m'
alias ..='cd ..'
alias ...='cd ../..'

# tmux-Griffe nachschlagen, ohne den Spickzettel zu suchen
alias hilfe='tmux-hilfe'

### fzf — der groesste Komfortgewinn, und er kostet nichts ------------------
# Strg+R  durchsucht die GESAMTE Befehlshistorie mit Fuzzy-Suche.
#         (Vorher: Pfeiltaste hoch, hundertmal.)
# Strg+T  fuegt einen Dateinamen aus dem aktuellen Baum ein.
# Alt+C   springt in ein Unterverzeichnis.
if command -v fzf >/dev/null 2>&1; then
	# Void legt die Shell-Anbindung hierhin. Pfad kann je nach Version
	# abweichen — darum beide Orte probieren.
	for f in /usr/share/fzf/key-bindings.bash /usr/share/fzf/completion.bash \
	         /usr/share/bash-completion/completions/fzf; do
		[ -r "$f" ] && . "$f"
	done
	# Neuere fzf-Versionen bringen die Anbindung selbst mit:
	eval "$(fzf --bash 2>/dev/null)" 2>/dev/null || true

	export FZF_DEFAULT_OPTS="--height 40% --layout=reverse --border --info=inline"
	command -v fd >/dev/null 2>&1 && export FZF_DEFAULT_COMMAND='fd --type f --hidden --exclude .git'
fi

### zoxide — 'z projekt' springt dorthin, wo man oft war --------------------
command -v zoxide >/dev/null 2>&1 && eval "$(zoxide init bash)"

### Tab-Vervollstaendigung -------------------------------------------------
# Fehlte komplett. Ohne das vervollstaendigt bash nur Dateinamen, keine
# Befehlsoptionen, keine git-Branches, keine Paketnamen.
[ -r /usr/share/bash-completion/bash_completion ] && . /usr/share/bash-completion/bash_completion

### Historie ---------------------------------------------------------------
# Damit Strg+R auch etwas zu finden hat.
HISTSIZE=10000
HISTFILESIZE=20000
HISTCONTROL=ignoreboth:erasedups     # keine Duplikate, keine Zeilen mit Leerzeichen
shopt -s histappend                  # anhaengen statt ueberschreiben
shopt -s checkwinsize                # Zeilenumbruch nach Fenstergroesse
PROMPT_COMMAND="history -a; ${PROMPT_COMMAND:-}"   # sofort schreiben, nicht erst beim Logout

### Editor -----------------------------------------------------------------
if command -v micro >/dev/null 2>&1; then
	export EDITOR=micro
	export VISUAL=micro
elif command -v vim >/dev/null 2>&1; then
	export EDITOR=vim
fi

### Prompt -----------------------------------------------------------------
# starship: zeigt Verzeichnis, Git-Zustand, Fehlercode. Konfiguration in
# ~/.config/starship.toml — dort auf 16 Farben und den Konsolenfont abgestimmt.
#
# Es rechnet bei JEDEM Enter kurz. Auf einem Atom N450 ist das messbar. Fuehlt
# es sich zaeh an: diese Zeile auskommentieren, dann greift der schlichte
# Prompt darunter.
if command -v starship >/dev/null 2>&1; then
	eval "$(starship init bash)"
else
	# Rueckfall: Nutzer, Verzeichnis, und ein roter Pfeil bei Fehler.
	PS1='\[\e[36m\]\w\[\e[0m\] \[\e[32m\]\$\[\e[0m\] '
fi
