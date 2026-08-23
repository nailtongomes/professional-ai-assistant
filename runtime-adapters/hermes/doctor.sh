#!/usr/bin/env bash
#
# Diagnóstico do runtime Hermes. Somente leitura.
#
# Exit: 0 ok | 1 degradado | 2 erro
set -Eeuo pipefail

ADAPTER_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${ADAPTER_DIR}/../.." && pwd)"
# shellcheck source=../../scripts/lib/common.sh
. "${REPO_ROOT}/scripts/lib/common.sh"

load_env
HOME_DIR="$(assistant_home)"
HERMES_ROOT="${HERMES_HOME:-${HOME_DIR}/.hermes}"

errors=0; warns=0
report() {
  printf '%-18s %s\n' "$1" "$2"
  case "$2" in ERROR*) errors=$((errors+1)) ;; WARN*) warns=$((warns+1)) ;; esac
}

report "Runtime" "hermes"

# binário e versão
if command -v hermes >/dev/null 2>&1; then
  bin="$(command -v hermes)"
  report "Runtime binary" "OK ${bin}"
  if version="$(hermes --version 2>/dev/null | head -n1)" && [[ -n "$version" ]]; then
    report "Runtime version" "OK ${version}"
  else
    report "Runtime version" "WARN não recuperável"
  fi
else
  report "Runtime binary" "WARN hermes não encontrado no PATH"
fi

# home do runtime
[[ -d "$HERMES_ROOT" ]] && report "Runtime home" "OK ${HERMES_ROOT}" \
                        || report "Runtime home" "WARN ausente: ${HERMES_ROOT}"

# brain canônico
[[ -f "${BRAIN_DIR}/INDEX.md" ]] && report "Brain" "OK ${BRAIN_DIR}" \
                                 || report "Brain" "ERROR brain não encontrado"

# mapeamento de Skills: symlinks apontando para o brain
link_count=0; broken=0
if [[ -d "${HERMES_ROOT}/skills" ]]; then
  while IFS= read -r -d '' link; do
    link_count=$((link_count + 1))
    [[ -e "$link" ]] || broken=$((broken + 1))
  done < <(find "${HERMES_ROOT}/skills" -maxdepth 1 -name 'pai-*' -type l -print0 2>/dev/null)
fi
if [[ $broken -gt 0 ]]; then
  report "Skills mapping" "ERROR ${broken} symlink(s) quebrado(s)"
elif [[ $link_count -gt 0 ]]; then
  report "Skills mapping" "OK ${link_count} Skill(s) mapeada(s)"
else
  report "Skills mapping" "WARN nenhuma Skill mapeada; rode configure.py"
fi

# artefato derivado
if [[ -f "${HERMES_ROOT}/SOUL.md" ]]; then
  grep -q "GERADO" "${HERMES_ROOT}/SOUL.md" 2>/dev/null \
    && report "Runtime context" "OK SOUL.md derivado" \
    || report "Runtime context" "WARN SOUL.md sem marca de arquivo gerado"
else
  report "Runtime context" "WARN SOUL.md ausente; rode configure.py"
fi

# acesso owner-only
gw_config="${HERMES_ROOT}/gateway.yaml"
if [[ -f "$gw_config" ]]; then
  if grep -qE '^\s*dm_policy:\s*allowlist' "$gw_config"; then
    if grep -qE '^\s*(dm_)?allow_from:' "$gw_config"; then
      report "Owner access" "OK dm_policy: allowlist com allow_from"
    else
      report "Owner access" "ERROR allowlist sem allow_from"
    fi
  elif grep -qE '^\s*dm_policy:\s*open' "$gw_config"; then
    report "Owner access" "ERROR dm_policy: open — acesso aberto"
  else
    report "Owner access" "WARN dm_policy não é allowlist"
  fi
else
  report "Owner access" "WARN gateway.yaml ausente; canal não configurado"
fi

# modelo/provider
if [[ -n "${ASSISTANT_MODEL:-}" || -n "${ASSISTANT_PROVIDER:-}" ]]; then
  report "Model config" "OK definido no assistant.env"
else
  report "Model config" "WARN ASSISTANT_MODEL/ASSISTANT_PROVIDER não definidos"
fi

printf '\n'
if [[ $errors -gt 0 ]]; then
  printf 'Hermes: ERROR (%d erro(s), %d aviso(s))\n' "$errors" "$warns"; exit 2
fi
if [[ $warns -gt 0 ]]; then
  printf 'Hermes: WARN (%d aviso(s))\n' "$warns"; exit 1
fi
printf 'Hermes: OK\n'
