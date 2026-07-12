# nb30

Samsung NB30 unter **Void Linux**: die Textkonsole plus **tmux** als Arbeitsplatz.
Kein Fenstermanager, kein Compile, kein Theming der Konsole. X startet nur, wenn ein
Browser gebraucht wird — und auch dann ohne WM.

Ersetzt [`dwm-nb30`](https://github.com/aesthut/dwm-nb30) und
[`tmux-nb30`](https://github.com/aesthut/tmux-nb30). Beide bleiben liegen und sind
notfalls klonbar; wer dwm zurückwill, kommt mit einem `git clone` dorthin.

## Installation

Void ist installiert, Netz und `ssh vps` stehen (siehe Vault-Notiz „NB30 — Void & tmux
Setup", Schritte 1–4). Dann:

```sh
git clone https://github.com/aesthut/nb30 && cd nb30 && ./install.sh
```

Danach `tmux` starten und einmalig `Strg+B`, dann großes `I` für die Plugins.

## Alltag

| | |
|---|---|
| `tmux` | der Arbeitsplatz. Aussteigen mit `Strg+B` dann `d` — es läuft weiter |
| `tmux attach` | wieder rein, genau wie vorher |
| `tmux-hilfe` | Spickzettel im Terminal |
| `tty-font` | Konsolenschriften ausprobieren und festlegen |
| `ssh vps` / `bmo` | alles, was rechnet |
| `w3m URL` | schnell nachschlagen, ohne X |
| `browser URL` | echte Webseite — startet X nur für den Browser |

## Statusleiste

Links der Sessionname und die **Prefix-Anzeige**: Sobald du `Strg+B` gedrückt hast und tmux
auf die nächste Taste wartet, leuchtet dort `TASTE` auf. Man sieht also, ob tmux zuhört,
statt zu raten — der größte Gewinn, solange die Griffe noch nicht sitzen.

Rechts CPU, RAM, Akku, Uhrzeit. Über `tmux-cpu` und `tmux-battery`.

Zwei bewusste Einstellungen:

- **`status-interval 15`**, nicht 1. Die Leiste startet bei jeder Aktualisierung
  Shell-Prozesse — im Sekundentakt würde der Atom N450 zu einem guten Teil sich selbst
  messen. Eine CPU-Anzeige, die CPU frisst, ist ein schlechter Witz.
- **Keine Icons.** Die Plugins zeigen standardmäßig Emoji und Batteriesymbole. Ein
  PSF-Konsolenfont trägt nur ein paar hundert Glyphen — die Icons erschienen dort als leere
  Kästchen. Also reiner Text und Prozentzahlen.

## Die Griffe

**Standard-tmux.** Vor jeder Taste: `Strg+B` drücken, loslassen.

| Taste | Aktion |
|---|---|
| `%` | nebeneinander teilen |
| `"` | übereinander teilen |
| Pfeiltasten | Feld wechseln |
| `Strg`+Pfeil | Feldgrenze verschieben |
| `z` | Feld groß/klein |
| `x` | Feld schließen |
| `c` | neues Fenster |
| `0` … `9` | Fenster wählen |
| `d` | raus — alles läuft weiter |
| `?` | alle Tastenkombinationen |

Keine eigene Belegung: Damit passt jede Anleitung im Netz, und der VPS (tmux ohne Config)
fühlt sich gleich an. Einzige Zugabe ist `Strg+B` dann `r` — Config neu laden. `r` ist im
Standard unbelegt.

## Was hier bewusst fehlt

**Kein Theming der Textkonsole.** Der Grund ist schwarz, die Schrift Terminus, fertig.

Die Linux-Konsole kann nur **16 Farben**. Nord ginge dort nur über die Kernel-Palette —
und die bringt den Framebuffer der GMA 3150 zum Glitchen: rosa und schwarze Sprenkel
überall dort, wo kein Text steht. Am 12.7.2026 real passiert, erst über kaputte
OSC-Sequenzen (`\e]PnRRGGBB`, die Index 0 auf ein Lila setzten), dann auch über
`setvtrgb`. Die einzige verlässliche Lösung ist, die Palette nicht anzufassen.

Aus demselben Grund enthält `.tmux.conf` **keine Hex-Farben**, sondern ANSI-Indizes
(`colour0`, `colour6`, …). So folgt tmux der Palette des Terminals, in dem es gerade
läuft — in der TTY die Standardfarben, in einem Terminal mit Nord-Palette automatisch
Nord. Eine Config, überall stimmig.

**Kein dwm, kein st, kein dmenu.** `browser` startet den Browser per `startx` als
Einzelanwendung; X existiert nur, solange der Browser läuft, und beim Schließen fällt man
zurück in tmux. Ein Fenstermanager wird dafür nicht gebraucht.

## Tastaturlayout

`KEYMAP="de-latin1-nodeadkeys"` in `/etc/rc.conf` setzt `install.sh`. Das ist Pflicht,
nicht Kosmetik: Ohne X gibt es niemanden, der `setxkbmap de` aufrufen könnte. Vorher blieb
die TTY auf US-QWERTY, und die Tilde (AltGr+Plus) traf ins Leere — der Fehler fiel monatelang
nicht auf, weil in X alles stimmte. `nodeadkeys`, damit `~ ^ \`` direkt kommen und nicht
zwei Anschläge brauchen.

## Notnagel-Browser (`browser`)

```sh
browser [URL]            # nimmt den ersten vorhandenen: luakit -> badwolf -> surf
browser --firefox [URL]  # nur im Notfall (zäh auf dem N450, aber Bank-Logins gehen)
```

WebKit läuft ohne Compositing und mit Software-GL (`LIBGL_ALWAYS_SOFTWARE=1`) — auf der
GMA 3150 gibt es kein Hardware-GL mehr. luakit braucht 250–400 MB je Tab, bei 2 GB RAM
also ein bis zwei Tabs.

## Harte Grenzen der Kiste

- **Atom N450**, x86-64-**v1** (kein SSE4.2). **Claude Code läuft hier nicht** — das
  Bun-Binary braucht v2 und stirbt mit SIGILL. Deshalb `ssh vps` / `bmo`.
- **2 GB RAM**, GMA 3150 ohne Hardware-GL → X11, kein Compositor, kein Wayland.
- WLAN Atheros AR9285 (`ath9k`), firmwarelos — läuft von selbst.
