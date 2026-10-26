#!/usr/bin/env python3
"""Converte saida/briefing.md em HTML simples (sem dependências).

Uso:  python scripts/renderizar_briefing.py [saida/briefing.md]
Gera saida/briefing-AAAA-MM-DD.html e imprime o caminho.
"""
import html
import re
import sys
from datetime import date

entrada = sys.argv[1] if len(sys.argv) > 1 else "saida/briefing.md"
linhas = open(entrada, encoding="utf8").read().splitlines()


def inline(t):
    t = html.escape(t)
    t = re.sub(r"\*\*(.+?)\*\*", r"<b>\1</b>", t)
    return re.sub(r"(https?://[^\s<)]+)", r'<a href="\1">\1</a>', t)


corpo, lista = [], False
for l in linhas:
    if lista and not l.startswith("- "):
        corpo.append("</ul>"); lista = False
    if l.startswith("### "):
        corpo.append(f"<h3>{inline(l[4:])}</h3>")
    elif l.startswith("## "):
        corpo.append(f"<h2>{inline(l[3:])}</h2>")
    elif l.startswith("# "):
        corpo.append(f"<h1>{inline(l[2:])}</h1>")
    elif l.startswith("- "):
        if not lista:
            corpo.append("<ul>"); lista = True
        corpo.append(f"<li>{inline(l[2:])}</li>")
    elif l.strip():
        corpo.append(f"<p>{inline(l)}</p>")
if lista:
    corpo.append("</ul>")

pagina = f"""<!doctype html><html lang="pt-BR"><meta charset="utf-8"><title>Radar {date.today()}</title>
<style>body{{font:18px/1.5 system-ui;max-width:780px;margin:40px auto;padding:0 20px;color:#1d1a16;background:#f6f0e2}}
h1{{font-size:34px}}h3{{margin-top:28px}}a{{color:#8a1f11}}</style><body>{"".join(corpo)}</body></html>"""
saida = f"saida/briefing-{date.today()}.html"
open(saida, "w", encoding="utf8").write(pagina)
print(saida)
