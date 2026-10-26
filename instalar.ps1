# Instalador do Radar do Curso (Windows, PowerShell). NÃO TESTADO no Windows.
#   iex (irm https://raw.githubusercontent.com/joaomatheuslf/oficina-hermes-radar/main/instalar.ps1)
# Para opções, baixe o arquivo e rode:  .\instalar.ps1 -SemAgentReach -Perfil nome -Pasta C:\caminho
param([switch]$SemAgentReach, [string]$Perfil = "", [string]$Pasta = "$HOME\oficina-hermes-radar")
$ErrorActionPreference = "Stop"
$Repo = "https://github.com/joaomatheuslf/oficina-hermes-radar.git"
function Ok($m)    { Write-Host "  [ok] $m" -ForegroundColor Green }
function Aviso($m) { Write-Host "  [!] $m" -ForegroundColor Yellow }
function Passo($m) { Write-Host "`n$m" -ForegroundColor Cyan }
function Falha($m) { Write-Host "  [x] $m" -ForegroundColor Red; throw $m }
$H = @(); if ($Perfil) { $H = @("-p", $Perfil) }

Passo "1/6 Conferindo o que já existe"
foreach ($c in "git", "python", "hermes") { if (-not (Get-Command $c -ErrorAction SilentlyContinue)) { Falha "$c não encontrado. Instale e rode de novo." } }
Ok "git, python e hermes encontrados"

Passo "2/6 Baixando o projeto em $Pasta"
if (Test-Path "$Pasta\.git") { git -C $Pasta pull --ff-only -q; Ok "projeto atualizado" } else { git clone -q $Repo $Pasta; Ok "projeto baixado" }

Passo "3/6 Instalando a skill radar-squad"
$Home_ = if ($env:HERMES_HOME) { $env:HERMES_HOME } else { "$HOME\.hermes" }
$Base = if ($Perfil) { "$Home_\profiles\$Perfil" } else { $Home_ }
New-Item -ItemType Directory -Force "$Base\skills\radar-squad" | Out-Null
Copy-Item "$Pasta\.hermes\skills\radar-squad\SKILL.md" "$Base\skills\radar-squad\SKILL.md" -Force
Ok "radar-squad copiada para $Base\skills"

Passo "4/6 Instalando as skills do Hermes"
try { hermes @H skills install official/research/rss-feeds --yes *> $null; Ok "rss-feeds instalada" } catch { Aviso "rss-feeds: confira com 'hermes skills list'" }
foreach ($s in "grounded-citations", "blocked-page-recovery") {
  if (Get-ChildItem "$Base\skills" -Directory -Recurse -Filter $s -ErrorAction SilentlyContinue | Select-Object -First 1) { Ok "$s já está no perfil"; continue }
  $o = foreach ($f in "$Home_\hermes-agent\skills", "$Home_\skills") { Get-ChildItem $f -Directory -Recurse -Filter $s -ErrorAction SilentlyContinue | Select-Object -First 1 } | Select-Object -First 1
  if ($o) { New-Item -ItemType Directory -Force "$Base\skills\$s" | Out-Null; Copy-Item "$($o.FullName)\*" "$Base\skills\$s" -Recurse -Force; Ok "$s copiada da instalação do Hermes" }
  else { Aviso "$s não encontrada. Atualize o Hermes (hermes update) e rode de novo." }
}

Passo "5/6 Agent Reach (ler web e GitHub)"
if ($SemAgentReach) { Aviso "pulado. O radar funciona só com os feeds." } else {
  try {
    if (-not (Get-Command uv -ErrorAction SilentlyContinue)) { powershell -ExecutionPolicy ByPass -c "irm https://astral.sh/uv/install.ps1 | iex"; $env:Path += ";$HOME\.local\bin" }
    # ATENÇÃO: o pacote "agent-reach" do PyPI NÃO é este projeto. Só instalamos pelo GitHub.
    uv tool install --force https://github.com/Panniantong/Agent-Reach/releases/latest/download/agent-reach.zip *> $null
    agent-reach setup *> $null; Ok "Agent Reach instalado"
  } catch { Aviso "Agent Reach não instalou. Siga o passo 3 do README ou use -SemAgentReach." }
}

Passo "6/6 Testando"
New-Item -ItemType Directory -Force "$Pasta\saida" | Out-Null
Push-Location $Pasta; try { python scripts\coletar_feeds.py --dias 7 --max 5 *> $null; Ok "coletor de feeds funcionando" } catch { Aviso "o coletor falhou (internet ou firewall?)" } finally { Pop-Location }
Aviso "Se 'hermes doctor' reclamar de chave de API ou Telegram, é normal até escolher um modelo (hermes setup)."
Write-Host "`nTudo pronto. Abra o Hermes dentro de $Pasta e peça: Use a skill radar-squad e gere o briefing de hoje."
