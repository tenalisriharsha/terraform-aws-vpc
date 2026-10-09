#!/usr/bin/env python3
"""Regenerate the terminal screenshots in docs/screenshots/.

Every image is produced by running the exact command shown in it from the
repository root and rendering its real, combined stdout/stderr (including
Terraform's ANSI colours). Nothing is typed or edited by hand: the only
additions are the window chrome, the "$ <command>" prompt line and an
"[exit status N]" footer taken from the command's real return code. Output
longer than MAX_LINES is cut and marked with "... (output truncated)".

Usage (from the repository root, with terraform and Pillow installed):

    python3 scripts/screenshots.py
"""

import os
import re
import subprocess
import sys

from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT_DIR = os.path.join(ROOT, "docs", "screenshots")

# Working directories are initialised first so the screenshots show the
# commands themselves, not provider downloads that vary by machine.
SETUP = [
    "terraform init -backend=false -input=false",
    "terraform -chdir=examples/complete init -backend=false -input=false",
]

SHOTS = [
    ("02-validate.png", "terraform validate"),
    ("03-test.png", "terraform test"),
    ("04-validate-json.png", "terraform validate -json | python3 -m json.tool"),
    ("05-complete-example.png", "terraform -chdir=examples/complete validate"),
]

MAX_LINES = 40

FONT_SIZE = 15
PAD = 20
TITLE_H = 36
BG = (13, 17, 23)
TITLE_BG = (30, 35, 43)
FG = (230, 237, 243)
DIM = (139, 148, 158)
PROMPT = (88, 166, 255)
ANSI = {
    30: (110, 118, 129), 31: (255, 123, 114), 32: (63, 185, 80),
    33: (210, 153, 34), 34: (88, 166, 255), 35: (188, 140, 255),
    36: (57, 197, 207), 37: (177, 186, 196),
}

SGR = re.compile(r"\x1b\[([0-9;]*)m")


def font(bold=False):
    name = "DejaVuSansMono-Bold.ttf" if bold else "DejaVuSansMono.ttf"
    for d in ("/usr/share/fonts/truetype/dejavu", "/Library/Fonts", "C:/Windows/Fonts"):
        path = os.path.join(d, name)
        if os.path.exists(path):
            return ImageFont.truetype(path, FONT_SIZE)
    sys.exit(f"font {name} not found; install DejaVu Sans Mono")


def parse(line, state):
    """Split one line into (text, colour, bold) runs, carrying SGR state."""
    runs, pos = [], 0
    for m in SGR.finditer(line):
        if m.start() > pos:
            runs.append((line[pos:m.start()], state["fg"], state["bold"]))
        for code in [int(c) for c in m.group(1).split(";") if c] or [0]:
            if code == 0:
                state.update(fg=FG, bold=False)
            elif code == 1:
                state["bold"] = True
            elif code == 39:
                state["fg"] = FG
            elif code in ANSI:
                state["fg"] = ANSI[code]
        pos = m.end()
    if pos < len(line):
        runs.append((line[pos:], state["fg"], state["bold"]))
    return runs


def run(cmd):
    proc = subprocess.run(
        ["bash", "-c", cmd], cwd=ROOT, stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT, text=True,
    )
    return proc.stdout, proc.returncode


def render(path, cmd, output, code):
    regular, bold = font(), font(bold=True)
    lines = output.rstrip("\n").split("\n")
    if len(lines) > MAX_LINES:
        lines = lines[:MAX_LINES] + ["... (output truncated)"]

    state = {"fg": FG, "bold": False}
    body = [[("$ ", PROMPT, True), (cmd, FG, True)]]
    body += [parse(line, state) for line in lines]
    body.append([(f"[exit status {code}]", ANSI[32] if code == 0 else ANSI[31], False)])

    char_w = regular.getlength("M")
    line_h = int(FONT_SIZE * 1.5)
    width = max(sum(len(t) for t, _, _ in runs) for runs in body)
    img_w = int(max(width * char_w, 600) + 2 * PAD)
    img_h = TITLE_H + PAD * 2 + line_h * len(body)

    img = Image.new("RGB", (img_w, img_h), BG)
    draw = ImageDraw.Draw(img)
    draw.rectangle([0, 0, img_w, TITLE_H], fill=TITLE_BG)
    for i, colour in enumerate([(255, 95, 86), (255, 189, 46), (39, 201, 63)]):
        cx = PAD + i * 20
        draw.ellipse([cx - 6, TITLE_H // 2 - 6, cx + 6, TITLE_H // 2 + 6], fill=colour)
    draw.text((PAD + 70, (TITLE_H - FONT_SIZE) // 2), "terraform-aws-vpc", font=regular, fill=DIM)

    y = TITLE_H + PAD
    for runs in body:
        x = PAD
        for text, colour, is_bold in runs:
            draw.text((x, y), text, font=bold if is_bold else regular, fill=colour)
            x += len(text) * char_w
        y += line_h
    img.save(path)


def main():
    for cmd in SETUP:
        out, code = run(cmd)
        if code != 0:
            sys.exit(f"setup failed: {cmd}\n{out}")
    for name, cmd in SHOTS:
        out, code = run(cmd)
        render(os.path.join(OUT_DIR, name), cmd, out, code)
        print(f"{name}: exit {code}")


if __name__ == "__main__":
    main()
