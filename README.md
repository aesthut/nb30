# nb30

Samsung NB30 unter **Void Linux**: **tmux** als Arbeitsplatz, in **st** als Leinwand.

**Kein Fenstermanager.** X trägt genau ein Terminal, bildschirmfüllend, und darin läuft
tmux. Die Fensterverwaltung macht tmux — Panes statt Fenster, Sessions statt Workspaces.
Schließt du tmux, endet st, endet X, und du bist zurück in der Textkonsole.

Warum X überhaupt, wenn es doch um die Konsole geht: Die Linux-Textkonsole kann nur
**16 Farben und Bitmap-Fonts**. In st gibt es **Truecolor** und eine **echte Schrift**
(JetBrains Mono, frei skalierbar). Das ist der einzige Grund. Es läuft kein WM, kein
Compositor, kein Panel — nur ein Terminal auf einem nackten X.

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
| `ssh vps` / `bmo` | alles, was rechnet |
| `w3m URL` | schnell nachschlagen, ohne X |
| `browser URL` | echte Webseite — startet X nur für den Browser |

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

## Optik

**In st: Nord, durchgängig.** Grund `#2e3440`, Statusleiste `#3b4252` (blaugrau), Akzent
Frost-Cyan `#88c0d0`. Schrift JetBrains Mono Medium. Größe ändern:
`ST_PIXELSIZE=17 ./install.sh`.

**In der Textkonsole: gar nichts.** Schwarzer Grund, Terminus fett (`ter-116b`). Die TTY
siehst du nur noch beim Einloggen, danach übernimmt X.

Das ist eine Entscheidung, keine Nachlässigkeit: Die Kernel-Palette bringt den Framebuffer
der GMA 3150 zum **Glitchen** — rosa und schwarze Sprenkel überall dort, wo kein Text
steht. Am 12.7.2026 real passiert, erst über kaputte OSC-Sequenzen (`\e]PnRRGGBB`, die
Index 0 auf ein Lila setzten), dann auch über `setvtrgb`. Die Palette wird nicht angefasst.

Zwei weitere Fallen der TTY, für den Fall, dass jemand es doch nochmal versucht: Der
**Hintergrund kann dort nur 8 Farben** (die hellen gibt es nur für Schrift), und **`bold`
hellt den Vordergrund auf** — fettes Schwarz ist grau, nicht schwarz, und verschwindet auf
hellem Grund.

**Kein dwm, kein dmenu, kein Panel.** `browser` startet den Browser ebenfalls per `startx`
als Einzelanwendung. Ein Fenstermanager wird nirgends gebraucht.

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
