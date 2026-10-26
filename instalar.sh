#!/usr/bin/env bash
# Instalador do Radar do Curso (Linux, Mac e WSL).
#   curl -fsSL https://raw.githubusercontent.com/joaomatheuslf/oficina-hermes-radar/main/instalar.sh | bash
# Opções (depois de "bash -s --"):  --sem-agent-reach   --perfil NOME   --pasta CAMINHO
set -euo pipefail

REPO="https://github.com/joaomatheuslf/oficina-hermes-radar.git"
PASTA="$HOME/oficina-hermes-radar"
PERFIL="${HERMES_PROFILE:-}"
AGENT_REACH=1
while [ $# -gt 0 ]; do
  case "$1" in
    --sem-agent-reach) AGENT_REACH=0 ;;
    --perfil) PERFIL="$2"; shift ;;
    --pasta) PASTA="$2"; shift ;;
    -h|--help) sed -n 2,4p "$0"; exit 0 ;;
    *) echo "Opção desconhecida: $1"; exit 2 ;;
  esac
  shift
done

ok()   { printf '  \033[32m✓\033[0m %s\n' "$*"; }
aviso(){ printf '  \033[33m!\033[0m %s\n' "$*"; }
falha(){ printf '  \033[31m✗\033[0m %s\n' "$*"; exit 1; }
passo(){ printf '\n\033[1m%s\033[0m\n' "$*"; }

H=(hermes); [ -n "$PERFIL" ] && H=(hermes -p "$PERFIL")

passo "1/6 Conferindo o que já existe"
command -v git >/dev/null     || falha "git não encontrado. Instale o git e rode de novo."
command -v python3 >/dev/null || falha "python3 não encontrado. Instale o Python 3 e rode de novo."
command -v hermes >/dev/null  || falha "hermes não encontrado. Instale o Hermes (Desktop ou CLI) antes: https://hermes-agent.nousresearch.com"
ok "git, python3 e hermes encontrados ($(hermes --version 2>/dev/null | head -1))"
[ -n "$PERFIL" ] && ok "usando o perfil do Hermes: $PERFIL"

passo "2/6 Baixando o projeto em $PASTA"
if [ -d "$PASTA/.git" ]; then
  git -C "$PASTA" pull --ff-only -q && ok "projeto atualizado"
else
  git clone -q "$REPO" "$PASTA" && ok "projeto baixado"
fi

passo "3/6 Instalando a skill radar-squad"
if [ -n "$PERFIL" ]; then BASE="${HERMES_HOME:-$HOME/.hermes}/profiles/$PERFIL"; else BASE="${HERMES_HOME:-$HOME/.hermes}"; fi
mkdir -p "$BASE/skills/radar-squad"
cp "$PASTA/.hermes/skills/radar-squad/SKILL.md" "$BASE/skills/radar-squad/SKILL.md"
ok "radar-squad copiada para $BASE/skills/"

passo "4/6 Instalando as skills do Hermes"
if "${H[@]}" skills install official/research/rss-feeds --yes >/dev/null 2>&1; then ok "rss-feeds instalada"
else aviso "rss-feeds: não consegui instalar agora (talvez já exista). Confira com: hermes skills list"; fi
FONTES=("${HERMES_HOME:-$HOME/.hermes}/hermes-agent/skills" "${HERMES_HOME:-$HOME/.hermes}/skills")
for s in grounded-citations blocked-page-recovery; do
  if [ -n "$(find "$BASE/skills" -type d -name "$s" 2>/dev/null | head -1)" ]; then ok "$s já está no perfil"; continue; fi
  ORIGEM=""
  for f in "${FONTES[@]}"; do ORIGEM="$(find "$f" -type d -name "$s" 2>/dev/null | head -1)"; [ -n "$ORIGEM" ] && break; done
  if [ -n "$ORIGEM" ]; then mkdir -p "$BASE/skills/$s"; cp -r "$ORIGEM/." "$BASE/skills/$s/"; ok "$s copiada da instalação do Hermes"
  else aviso "$s não encontrada. Atualize o Hermes (hermes update) e rode este instalador de novo."; fi
done

passo "5/6 Agent Reach (ler web e GitHub)"
if [ "$AGENT_REACH" = 0 ]; then
  aviso "pulado (--sem-agent-reach). O radar funciona só com os feeds."
else
  command -v uv >/dev/null || { aviso "instalando o uv (gerenciador de ferramentas Python, sem senha de administrador)"; curl -LsSf https://astral.sh/uv/install.sh | sh; export PATH="$HOME/.local/bin:$PATH"; }
  # ATENÇÃO: o pacote "agent-reach" do PyPI NÃO é este projeto. Só instalamos pelo GitHub.
  uv tool install --force https://github.com/Panniantong/Agent-Reach/releases/latest/download/agent-reach.zip >/dev/null 2>&1 \
    && agent-reach setup >/dev/null 2>&1 \
    && ok "Agent Reach instalado (canais sem login: web e GitHub)" \
    || aviso "Agent Reach não instalou. Siga o passo 3 do README ou use --sem-agent-reach."
fi

passo "6/6 Testando"
mkdir -p "$PASTA/saida"
if (cd "$PASTA" && python3 scripts/coletar_feeds.py --dias 7 --max 5 >/dev/null); then ok "coletor de feeds funcionando"
else aviso "o coletor falhou (internet ou firewall?). Rode: python3 scripts/coletar_feeds.py"; fi
LISTA="$("${H[@]}" skills list 2>/dev/null || true)"
printf '%s' "$LISTA" | grep -q radar-squad && ok "radar-squad aparece em 'hermes skills list'" || aviso "radar-squad não apareceu em 'hermes skills list'."
aviso "Se 'hermes doctor' reclamar de chave de API ou Telegram, é normal até você escolher um modelo (hermes setup)."

cat <<MSG

Tudo pronto. Próximo passo, dentro da pasta do projeto:

  cd "$PASTA"
  hermes${PERFIL:+ -p $PERFIL}

e peça ao agente:  Use a skill radar-squad e gere o briefing de hoje.
O resultado fica em saida/briefing-AAAA-MM-DD.html
MSG
