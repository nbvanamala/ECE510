#!/usr/bin/env python3
"""
build_pdf.py  —  Converts design_justification.md to design_justification.pdf
Run from any directory:  python3 build_pdf.py
"""
import re
from pathlib import Path

from reportlab.lib import colors
from reportlab.lib.enums import TA_CENTER, TA_JUSTIFY, TA_LEFT
from reportlab.lib.pagesizes import letter
from reportlab.lib.styles import ParagraphStyle
from reportlab.lib.units import inch
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.pdfmetrics import registerFontFamily
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.platypus import (
    HRFlowable, Paragraph, SimpleDocTemplate, Spacer, Table, TableStyle,
    Image as RLImage,
)
from PIL import Image as PILImage

# ---------------------------------------------------------------------------
# Fonts
# ---------------------------------------------------------------------------
_FONT_DIR = Path("C:/Windows/Fonts")
for _name, _file in [
    ("Arial",            "arial.ttf"),
    ("Arial-Bold",       "arialbd.ttf"),
    ("Arial-Italic",     "ariali.ttf"),
    ("Arial-BoldItalic", "arialbi.ttf"),
    ("CourierNew",       "cour.ttf"),
    ("CourierNew-Bold",  "courbd.ttf"),
]:
    _path = _FONT_DIR / _file
    if _path.exists():
        pdfmetrics.registerFont(TTFont(_name, str(_path)))

registerFontFamily(
    "Arial",
    normal="Arial",
    bold="Arial-Bold",
    italic="Arial-Italic",
    boldItalic="Arial-BoldItalic",
)

# ---------------------------------------------------------------------------
# Layout
# ---------------------------------------------------------------------------
PAGE_W, PAGE_H = letter
LM = RM = 1.05 * inch
TM = BM = 0.95 * inch
TEXT_W = PAGE_W - LM - RM          # ≈ 453 pt  (6.29 in)

NAVY       = colors.HexColor("#1a3a5c")
LTBLUE     = colors.HexColor("#2c5f8a")
GRAY       = colors.HexColor("#555555")
HEADER_BG  = colors.HexColor("#1a3a5c")
ALT_BG     = colors.HexColor("#eef2f7")
CODE_BG    = colors.HexColor("#f4f4f4")
RULE_COLOR = colors.HexColor("#aaaaaa")

# ---------------------------------------------------------------------------
# Styles
# ---------------------------------------------------------------------------
def _P(name, **kw):
    return ParagraphStyle(name, **kw)

ST = {
    "h1":     _P("H1",    fontName="Arial-Bold",   fontSize=18, leading=22,
                           spaceAfter=5,  textColor=NAVY, alignment=TA_CENTER),
    "h2sub":  _P("H2S",   fontName="Arial-Bold",   fontSize=12, leading=15,
                           spaceAfter=3,  textColor=NAVY, alignment=TA_CENTER),
    "h3sub":  _P("H3S",   fontName="Arial-Italic", fontSize=11, leading=14,
                           spaceAfter=3,  textColor=GRAY, alignment=TA_CENTER),
    "sec":    _P("Sec",   fontName="Arial-Bold",   fontSize=13, leading=17,
                           spaceBefore=18, spaceAfter=8, textColor=NAVY),
    "subsec": _P("SS",    fontName="Arial-Bold",   fontSize=11, leading=14,
                           spaceBefore=10, spaceAfter=5, textColor=LTBLUE),
    "body":   _P("Bd",    fontName="Arial",        fontSize=10.5, leading=14.5,
                           spaceAfter=8,  alignment=TA_JUSTIFY),
    "bullet": _P("Bu",    fontName="Arial",        fontSize=10.5, leading=14,
                           leftIndent=20, firstLineIndent=-10, spaceAfter=3),
    "code":   _P("Co",    fontName="CourierNew",   fontSize=8.5, leading=11,
                           leftIndent=16, spaceAfter=8, backColor=CODE_BG,
                           borderPadding=(3, 6, 3, 6)),
    "note":   _P("No",    fontName="Arial-Italic", fontSize=9.5, leading=13,
                           textColor=GRAY, alignment=TA_JUSTIFY),
    "th":     _P("TH",    fontName="Arial-Bold",   fontSize=9,   leading=11,
                           textColor=colors.white),
    "td":     _P("TD",    fontName="Arial",        fontSize=9,   leading=11.5),
    "tdcode": _P("TDc",   fontName="CourierNew",   fontSize=8.5, leading=10.5),
}

# ---------------------------------------------------------------------------
# Inline markdown → ReportLab XML
# ---------------------------------------------------------------------------
def _inline(text: str) -> str:
    """Bold/italic/code markdown → ReportLab Paragraph XML markup."""
    # XML-escape first so our injected tags aren't double-escaped
    text = text.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")
    # Bold+italic  ***text***
    text = re.sub(r"\*\*\*(.+?)\*\*\*", r"<b><i>\1</i></b>", text)
    # Bold         **text**
    text = re.sub(r"\*\*(.+?)\*\*", r"<b>\1</b>", text)
    # Italic       *text*  (single asterisk, not double)
    text = re.sub(r"(?<!\*)\*(?!\*)(.+?)(?<!\*)\*(?!\*)", r"<i>\1</i>", text)
    # Inline code  `text`
    text = re.sub(r"`([^`]+)`",
                  r'<font face="CourierNew" fontSize="9">\1</font>', text)
    return text

# ---------------------------------------------------------------------------
# Table builder
# ---------------------------------------------------------------------------
def _col_widths(ncols: int) -> list:
    W = TEXT_W
    if ncols == 2:
        return [W * 0.40, W * 0.60]
    if ncols == 3:
        return [W * 0.30, W * 0.35, W * 0.35]
    if ncols == 4:
        return [W * 0.22, W * 0.22, W * 0.22, W * 0.34]
    if ncols == 5:
        # Register map: Address, Register, Width, Direction, Description
        return [W * 0.09, W * 0.12, W * 0.07, W * 0.12, W * 0.60]
    if ncols == 6:
        # Power table: Group, Internal, Switching, Leakage, Total, Fraction
        return [W * 0.16, W * 0.17, W * 0.17, W * 0.14, W * 0.20, W * 0.16]
    return [W / ncols] * ncols


def _build_table(md_lines: list):
    rows = []
    for line in md_lines:
        line = line.strip()
        # skip separator lines  |---|---|
        if re.match(r"^\|[-| :]+\|$", line):
            continue
        cells = [c.strip() for c in line.strip("|").split("|")]
        rows.append(cells)
    if not rows:
        return None

    ncols   = max(len(r) for r in rows)
    cw      = _col_widths(ncols)
    fs      = 8 if ncols >= 6 else (8.5 if ncols == 5 else 9)
    fs_lead = fs + 2

    def _cell_para(text, is_header):
        fn  = "Arial-Bold" if is_header else "Arial"
        ftc = colors.white if is_header else colors.black
        # use monospace for cells that look like hex/code  0x.. or [n:n]
        if not is_header and re.match(r"^(0x|`|\[)", text):
            fn = "CourierNew"
        style = ParagraphStyle(
            "c", fontName=fn, fontSize=fs, leading=fs_lead, textColor=ftc
        )
        return Paragraph(_inline(text), style)

    data = []
    for ri, row in enumerate(rows):
        row = (row + [""] * ncols)[:ncols]
        data.append([_cell_para(c, ri == 0) for c in row])

    tbl = Table(data, colWidths=cw, repeatRows=1)
    tbl.setStyle(TableStyle([
        ("BACKGROUND",    (0, 0), (-1, 0),  HEADER_BG),
        ("GRID",          (0, 0), (-1, -1), 0.4, colors.HexColor("#c0c0c0")),
        ("ROWBACKGROUNDS",(0, 1), (-1, -1), [colors.white, ALT_BG]),
        ("VALIGN",        (0, 0), (-1, -1), "TOP"),
        ("TOPPADDING",    (0, 0), (-1, -1), 4),
        ("BOTTOMPADDING", (0, 0), (-1, -1), 4),
        ("LEFTPADDING",   (0, 0), (-1, -1), 5),
        ("RIGHTPADDING",  (0, 0), (-1, -1), 5),
    ]))
    return tbl

# ---------------------------------------------------------------------------
# Header / footer callback
# ---------------------------------------------------------------------------
def _hf(canvas, doc):
    canvas.saveState()
    W, H = letter
    # ── header ─────────────────────────────────────────────
    y_hdr = H - TM + 14
    canvas.setStrokeColor(NAVY)
    canvas.setLineWidth(0.75)
    canvas.line(LM, y_hdr - 2, W - RM, y_hdr - 2)
    canvas.setFont("Arial-Bold", 7.5)
    canvas.setFillColor(NAVY)
    canvas.drawString(LM, y_hdr + 2,
                      "Edge CNN Accelerator — Design Justification Report")
    canvas.setFont("Arial", 7.5)
    canvas.drawRightString(W - RM, y_hdr + 2,
                           "Naveen Babu Vanamala  |  ECE 510 Spring 2026")
    # ── footer ─────────────────────────────────────────────
    y_ftr = BM - 12
    canvas.setStrokeColor(RULE_COLOR)
    canvas.setLineWidth(0.5)
    canvas.line(LM, y_ftr + 8, W - RM, y_ftr + 8)
    canvas.setFont("Arial", 7.5)
    canvas.setFillColor(GRAY)
    canvas.drawCentredString(W / 2, y_ftr - 2, f"— {doc.page} —")
    canvas.restoreState()

# ---------------------------------------------------------------------------
# Markdown → flowables
# ---------------------------------------------------------------------------
def _md_to_story(md: str) -> list:
    lines  = md.split("\n")
    story  = []
    i      = 0
    in_title = True   # before the first ---

    while i < len(lines):
        line = lines[i]

        # ── headings ──────────────────────────────────────
        m = re.match(r"^(#{1,3}) (.+)$", line)
        if m:
            level = len(m.group(1))
            text  = m.group(2).strip()
            if level == 1:
                story.append(Paragraph(_inline(text), ST["h1"]))
            elif level == 2 and in_title:
                story.append(Paragraph(_inline(text), ST["h2sub"]))
            elif level == 3 and in_title:
                story.append(Paragraph(_inline(text), ST["h3sub"]))
            elif level == 2:
                story.append(Paragraph(_inline(text), ST["sec"]))
            else:
                story.append(Paragraph(_inline(text), ST["subsec"]))
            i += 1
            continue

        # ── horizontal rule ---  ──────────────────────────
        if line.strip() == "---":
            if in_title:
                # title-section divider
                story.append(Spacer(1, 6))
                story.append(HRFlowable(width="100%", thickness=1.5,
                                        color=NAVY, spaceAfter=14))
                in_title = False
            else:
                story.append(Spacer(1, 6))
                story.append(HRFlowable(width="100%", thickness=0.5,
                                        color=RULE_COLOR, spaceAfter=6))
            i += 1
            continue

        # ── table ─────────────────────────────────────────
        if line.startswith("|"):
            tbl_lines = []
            while i < len(lines) and lines[i].startswith("|"):
                tbl_lines.append(lines[i])
                i += 1
            tbl = _build_table(tbl_lines)
            if tbl:
                story.append(Spacer(1, 4))
                story.append(tbl)
                story.append(Spacer(1, 8))
            continue

        # ── fenced code block ─────────────────────────────
        if line.startswith("```"):
            code_lines = []
            i += 1
            while i < len(lines) and not lines[i].startswith("```"):
                raw = (lines[i]
                       .replace("&", "&amp;")
                       .replace("<", "&lt;")
                       .replace(">", "&gt;"))
                code_lines.append(raw)
                i += 1
            if i < len(lines):
                i += 1
            if code_lines:
                story.append(
                    Paragraph("<br/>".join(code_lines), ST["code"])
                )
            continue

        # ── bullet list ───────────────────────────────────
        if re.match(r"^- ", line):
            while i < len(lines) and re.match(r"^- ", lines[i]):
                item = lines[i][2:].strip()
                # continuation lines (indented)
                i += 1
                while i < len(lines) and lines[i].startswith("  "):
                    item += " " + lines[i].strip()
                    i += 1
                story.append(
                    Paragraph("&#x2022;&nbsp;&nbsp;" + _inline(item),
                              ST["bullet"])
                )
            story.append(Spacer(1, 3))
            continue

        # ── inline image  ![caption](path) ───────────────
        if line.startswith("!["):
            m = re.match(r"!\[([^\]]*)\]\(([^)]+)\)", line)
            if m:
                caption  = m.group(1)
                rel_path = m.group(2)
                img_path = Path("C:/Users/navee/ECE510/project/m4/report") / rel_path
                if img_path.exists():
                    try:
                        pil  = PILImage.open(str(img_path))
                        pw, ph = pil.size
                        max_w = TEXT_W * 0.95
                        max_h = 3.8 * inch
                        scale = min(max_w / pw, max_h / ph)
                        iw, ih = pw * scale, ph * scale
                        cap_st = ParagraphStyle(
                            "Cap", fontName="Arial-Italic", fontSize=8.5,
                            leading=11, alignment=TA_CENTER,
                            textColor=GRAY, spaceAfter=10, spaceBefore=2)
                        story.append(Spacer(1, 8))
                        story.append(RLImage(str(img_path), width=iw, height=ih))
                        story.append(Paragraph(_inline(caption), cap_st))
                        story.append(Spacer(1, 6))
                    except Exception as e:
                        story.append(Paragraph(f"[Figure: {caption}]", ST["note"]))
            i += 1
            continue

        # ── blank line ────────────────────────────────────
        if line.strip() == "":
            i += 1
            continue

        # ── paragraph: accumulate until blank / heading / special ─
        para_parts = []
        while i < len(lines):
            l = lines[i]
            if (l.strip() == "" or re.match(r"^#{1,3} ", l) or
                    l.startswith("|") or l.startswith("```") or
                    l.strip() == "---" or re.match(r"^- ", l) or
                    l.startswith("![")):
                break
            para_parts.append(l)
            i += 1

        if not para_parts:
            continue

        raw = " ".join(para_parts)

        # Italic-only paragraph  *...*  (closing footnote)
        if (raw.startswith("*") and raw.endswith("*")
                and not raw.startswith("**")):
            inner = raw[1:-1]
            story.append(Spacer(1, 8))
            story.append(HRFlowable(width="100%", thickness=0.5,
                                    color=RULE_COLOR, spaceAfter=4))
            story.append(Paragraph(_inline(inner), ST["note"]))
            continue

        # Bold subsection heading  **N.N Title...**
        if re.match(r"^\*\*\d+\.\d+\s", raw):
            story.append(Paragraph(_inline(raw), ST["subsec"]))
            continue

        # Normal paragraph
        story.append(Paragraph(_inline(raw), ST["body"]))

    return story

# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------
def main():
    base   = Path("C:/Users/navee/ECE510/project/m4/report")
    md_in  = base / "design_justification.md"
    pdf_out = base / "design_justification.pdf"

    print(f"Reading  {md_in}")
    md_text = md_in.read_text(encoding="utf-8")

    doc = SimpleDocTemplate(
        str(pdf_out),
        pagesize=letter,
        leftMargin=LM,
        rightMargin=RM,
        topMargin=TM + 26,
        bottomMargin=BM + 20,
        title="Design Justification Report — Edge CNN Accelerator",
        author="Naveen Babu Vanamala",
        subject="ECE 510 Spring 2026 M4",
    )

    story = _md_to_story(md_text)
    doc.build(story, onFirstPage=_hf, onLaterPages=_hf)

    print(f"PDF written to: {pdf_out}  ({doc.page} pages)")


if __name__ == "__main__":
    main()
