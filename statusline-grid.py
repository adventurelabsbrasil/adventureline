#!/usr/bin/env python3
"""Layout helper for adventureline (aligned grid + themed labels).

stdin: cells, one per line, each "EMOJI\x1fLABEL\x1fVALUE" (0x1f = unit sep;
EMOJI may be empty). Groups separated by a line with a single 0x1e byte. Cells
are laid out in NCOLS columns; within each column the "EMOJI LABEL:" part is
padded so every VALUE starts at the same position (Gemini-style alignment).

Theme knobs come from the environment (set by statusline.sh):
  AL_GRAD       "r,g,b;r,g,b;..."  gradient stops for labels ("" = no color)
  AL_LABELSTYLE "gradient" | "bold"

argv: NCOLS  COLBUDGET   (COLBUDGET = target visible width per column)
"""
import os, sys, re, unicodedata

ncols     = int(sys.argv[1]) if len(sys.argv) > 1 else 2
colbudget = int(sys.argv[2]) if len(sys.argv) > 2 else 37
RST = "\x1b[0m"

LABELSTYLE = os.environ.get("AL_LABELSTYLE", "gradient")
SEP = "\x1b[2m │ \x1b[0m" if LABELSTYLE == "gradient" else "  |  "


def parse_stops(s):
    stops = []
    for part in s.split(";"):
        try:
            r, g, b = (int(x) for x in part.split(","))
            stops.append((r, g, b))
        except Exception:
            pass
    return stops


STOPS = parse_stops(os.environ.get("AL_GRAD", ""))


def grad(t):
    if not STOPS:
        return ""
    if len(STOPS) == 1:
        r, g, b = STOPS[0]
    else:
        seg = t * (len(STOPS) - 1)
        i = min(int(seg), len(STOPS) - 2)
        f = seg - i
        (r0, g0, b0), (r1, g1, b1) = STOPS[i], STOPS[i + 1]
        r = round(r0 + (r1 - r0) * f)
        g = round(g0 + (g1 - g0) * f)
        b = round(b0 + (b1 - b0) * f)
    return f"\x1b[38;2;{r};{g};{b}m"


ANSI   = re.compile(r'\x1b\[[0-9;]*m')
CLOCKS = set(range(0x23E9, 0x23F4)) | {0x231A, 0x231B}


def cw(ch):
    if ch in ('️', '‍') or unicodedata.combining(ch):
        return 0
    cp = ord(ch)
    if unicodedata.east_asian_width(ch) in ('W', 'F'):
        return 2
    if (0x1F000 <= cp <= 0x1FAFF or 0x2600 <= cp <= 0x27BF
            or 0x2B00 <= cp <= 0x2BFF or cp in CLOCKS):
        return 2
    return 1


def vis(s):
    return sum(cw(c) for c in ANSI.sub('', s))


def trunc(s, capw):
    if capw <= 1 or vis(s) <= capw:
        return s
    out, w, i = [], 0, 0
    while i < len(s):
        m = ANSI.match(s, i)
        if m:
            out.append(m.group()); i = m.end(); continue
        ch = s[i]; i += 1
        c = cw(ch)
        if w + c > capw - 1:
            break
        out.append(ch); w += c
    return ''.join(out) + RST + '…'


def label_disp(emoji, label):
    return f"{emoji} {label}:" if emoji else f"{label}:"


def style_label(disp, t):
    if LABELSTYLE == "gradient":
        return f"{grad(t)}{disp}{RST}"
    if LABELSTYLE == "bold":
        return f"\x1b[1m{disp}{RST}"
    return disp


# ── parse groups of (emoji, label, value) ────────────────────────────────────
groups, cur = [], []
for line in sys.stdin.read().split('\n'):
    if line == '\x1e':
        groups.append(cur); cur = []
    elif line != '':
        parts = line.split('\x1f')
        if len(parts) == 3:
            cur.append(tuple(parts))
groups.append(cur)

rows = []
for g in groups:
    for i in range(0, len(g), ncols):
        rows.append(g[i:i + ncols])
rows = [r for r in rows if r]
if not rows:
    sys.exit(0)

# per-column label width (labels never truncated)
lw = [0] * ncols
for r in rows:
    for j, (emoji, label, _v) in enumerate(r):
        lw[j] = max(lw[j], vis(label_disp(emoji, label)))

# truncate values to remaining budget
rows2 = []
for r in rows:
    nr = []
    for j, (emoji, label, val) in enumerate(r):
        valcap = max(6, colbudget - lw[j] - 1)
        nr.append((emoji, label, trunc(val, valcap)))
    rows2.append(nr)

vw = [0] * ncols
for r in rows2:
    for j, (_e, _l, val) in enumerate(r):
        vw[j] = max(vw[j], vis(val))

# render
total = len(rows2)
out = []
for ri, r in enumerate(rows2):
    t = ri / (total - 1) if total > 1 else 0.0
    cells = []
    for j, (emoji, label, val) in enumerate(r):
        disp = label_disp(emoji, label)
        lab = style_label(disp, t)
        pad_label = lw[j] - vis(disp)
        cell = f"{lab}{' ' * pad_label} {val}"
        if j < len(r) - 1:
            cell += ' ' * (vw[j] - vis(val))
        cells.append(cell)
    out.append(SEP.join(cells))
sys.stdout.write('\n'.join(out))
