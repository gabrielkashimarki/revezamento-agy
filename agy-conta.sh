#!/bin/bash
# Roda o agy (Antigravity CLI) numa conta Google específica; várias contas rodam ao mesmo tempo.
# Funciona no macOS e no Linux (inclusive WSL, que é o caminho no Windows).
#
# Uso: agy-conta.sh <nome> [argumentos do agy]
#      agy-conta.sh <nome> --logar        (abre o agy interativo para logar essa conta)
#
# Conta "principal" usa o HOME normal; qualquer outro nome usa ~/agy-<nome> como HOME.
#
# Linux: o agy já guarda o token no arquivo do HOME, então basta trocar o HOME. O dbus vai
# desligado para nenhuma versão futura cair no chaveiro do sistema, que é um só por usuário.
#
# macOS, por que o sandbox: o agy guarda o login no Keychain, num item único por usuário do macOS,
# então trocar só o HOME não separa as contas. Quando o Keychain falha, ele usa o arquivo
# <HOME>/.gemini/antigravity-cli/antigravity-oauth-token. Proibindo o /usr/bin/security
# (que o go-keyring chama), cada conta lê e renova o token só no arquivo do próprio HOME.
# Efeito colateral: os filhos do agy também não rodam o security. Quem precisa do token do
# 1Password deve recebê-lo já no ambiente (OP_SERVICE_ACCOUNT_TOKEN).
set -uo pipefail

NOME=${1:?informe a conta (principal ou outro nome)}; shift
case $NOME in
  principal) CASA=$HOME ;;
  *[!a-zA-Z0-9._-]*) echo "nome de conta inválido: $NOME" >&2; exit 2 ;;
  *) CASA=$HOME/agy-$NOME ;;
esac
AGY=$(command -v agy || echo "$HOME/.local/bin/agy")
[ -x "$AGY" ] || { echo "agy não encontrado" >&2; exit 2; }
case $(uname -s) in
  Darwin|Linux) ;;
  *) echo "sistema não suportado: no Windows, rode dentro do WSL" >&2; exit 2 ;;
esac

ARQ=$CASA/.gemini/antigravity-cli/antigravity-oauth-token
if [ ! -s "$ARQ" ] && [ "${1:-}" != "--logar" ]; then
  echo "conta $NOME sem login: rode 'agy-conta.sh $NOME --logar'" >&2; exit 3
fi
mkdir -p "$CASA"

[ "${1:-}" = "--logar" ] && set --

if [ "$(uname -s)" = Linux ]; then
  HOME=$CASA DBUS_SESSION_BUS_ADDRESS=disabled: exec "$AGY" "$@"
fi

PERFIL=$(mktemp -t agy-conta); trap 'rm -f "$PERFIL"' EXIT
printf '(version 1)\n(allow default)\n(deny process-exec (literal "/usr/bin/security"))\n' > "$PERFIL"
HOME=$CASA sandbox-exec -f "$PERFIL" "$AGY" "$@"
