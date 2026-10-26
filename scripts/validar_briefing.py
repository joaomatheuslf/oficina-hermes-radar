#!/usr/bin/env python3
"""Barreira em código: todo destaque do briefing precisa de link, e o link precisa vir da coleta.

Uso:  python scripts/validar_briefing.py [saida/briefing.md] [saida/coleta.json]
Sai com código 1 se algo estiver errado (o agente deve corrigir e rodar de novo).
"""
import json
import re
import sys

md = sys.argv[1] if len(sys.argv) > 1 else "saida/briefing.md"
col = sys.argv[2] if len(sys.argv) > 2 else "saida/coleta.json"
texto = open(md, encoding="utf8").read()
problemas = []

destaques = [b for b in re.split(r"\n(?=### )", texto) if b.startswith("### ")]
if not destaques:
    problemas.append("nenhum destaque encontrado (use '### ' para cada destaque)")
for b in destaques:
    titulo = b.splitlines()[0][4:]
    if not re.search(r"https?://", b):
        problemas.append(f"sem link: {titulo}")

try:
    bruto = open(col, encoding="utf8").read()
    permitidos = set(re.findall(r"https?://[^\s\"'<>)\]]+", bruto))
    for u in set(re.findall(r"https?://[^\s\"'<>)\]]+", texto)):
        if u.rstrip(".,;") not in permitidos and not any(u.startswith(p) for p in permitidos):
            problemas.append(f"link que não veio da coleta: {u}")
except FileNotFoundError:
    problemas.append(f"coleta não encontrada: {col}")

if problemas:
    print("REPROVADO")
    for p in problemas:
        print(" -", p)
    sys.exit(1)
print(f"APROVADO: {len(destaques)} destaques, todos com fonte da coleta")
