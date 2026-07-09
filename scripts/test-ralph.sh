#!/usr/bin/env bash
#
# test-ralph.sh — suite red/green do scripts/ralph.sh com engine mock.
#
# Nenhuma chamada de rede, nenhum token gasto: binarios fake `claude` e `codex`
# entram no PATH e o comportamento e escolhido por MOCK_SCENARIO.
#
# Uso: scripts/test-ralph.sh [nome-do-caso]   (exit 0 = tudo verde)

set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# RALPH_BIN permite apontar para uma copia patchada (prova red dos testes).
RALPH="${RALPH_BIN:-$ROOT/scripts/ralph.sh}"
ONLY="${1:-}"

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

PASS=0
FAIL=0
CURRENT=""

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'

ok()   { PASS=$((PASS + 1)); echo -e "  ${GREEN}ok${NC}   $1"; }
bad()  { FAIL=$((FAIL + 1)); echo -e "  ${RED}FAIL${NC} $1"; }

assert_eq() {
  local expected="$1" actual="$2" msg="$3"
  if [ "$expected" = "$actual" ]; then ok "$msg"; else bad "$msg (esperado '$expected', veio '$actual')"; fi
}

assert_contains() {
  local haystack_file="$1" needle="$2" msg="$3"
  if grep -qF "$needle" "$haystack_file"; then ok "$msg"; else bad "$msg (nao achou '$needle')"; fi
}

assert_not_contains() {
  local haystack_file="$1" needle="$2" msg="$3"
  if grep -qF "$needle" "$haystack_file"; then bad "$msg (achou '$needle')"; else ok "$msg"; fi
}

# ---------------------------------------------------------------------------
# Mock engine — vale para claude e codex (dispatch por basename)
# ---------------------------------------------------------------------------

make_mocks() {
  local bin="$1"
  mkdir -p "$bin"

  cat > "$bin/mock-engine" <<'MOCK'
#!/usr/bin/env bash
set -uo pipefail

name=$(basename "$0")
state="${MOCK_STATE:?}"
scenario="${MOCK_SCENARIO:-ok}"
prompt=""
verify=0

bump() {
  local f="$state/$1" n=0
  [ -f "$f" ] && n=$(cat "$f")
  n=$((n + 1))
  echo "$n" > "$f"
  echo "$n"
}

if [ "$name" = "claude" ]; then
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -p) prompt="$2"; shift 2 ;;
      --allowedTools) verify=1; shift 2 ;;
      --output-format) shift 2 ;;
      *) shift ;;
    esac
  done
else
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --sandbox) [ "$2" = "read-only" ] && verify=1; shift 2 ;;
      *) shift ;;
    esac
  done
  prompt=$(cat)
fi

grep -q '^RALPH_VERIFY' <<< "$prompt" && verify=1

# --- verificador independente ------------------------------------------------
if [ "$verify" -eq 1 ]; then
  n=$(bump verify_calls)
  tasks=$(grep -cE '^[[:space:]]*- \[[ x]\]' <<< "$prompt")
  if [ "$scenario" = "verify-incomplete-once" ] && [ "$n" -eq 1 ]; then
    echo "TASK 1: INCOMPLETE — o arquivo nao foi criado"
    for i in $(seq 2 "$tasks"); do echo "TASK $i: DONE"; done
  else
    for i in $(seq 1 "$tasks"); do echo "TASK $i: DONE"; done
  fi
  exit 0
fi

# --- sessao de implementacao -------------------------------------------------
n=$(bump impl_calls)

emit_claude_ok()    { echo '{"type":"result","subtype":"success","is_error":false,"result":"implementado"}'; }
emit_claude_limit() { echo "{\"type\":\"result\",\"subtype\":\"error\",\"is_error\":true,\"result\":\"Claude AI usage limit reached|$1\"}"; }

case "$scenario" in
  limit-epoch)
    if [ "$n" -eq 1 ]; then
      emit_claude_limit "$(date +%s)"
      exit 1
    fi
    ;;
  limit-generic)
    if [ "$n" -eq 1 ]; then
      echo "Rate limit reached. Try again later."
      exit 1
    fi
    ;;
esac

# stall-after-red: escreve no 1o ciclo (teste vermelho), depois trava sem
# escrever nada. O diff herdado do ciclo 1 nao pode passar o gate 1 de graca.
write=1
[ "$scenario" = "empty-diff" ] && write=0
[ "$scenario" = "stall-after-red" ] && [ "$n" -gt 1 ] && write=0

if [ "$write" -eq 1 ]; then
  mkdir -p src
  echo "impl $n" > "src/impl-$n.txt"
fi

if [ "$scenario" = "false-429" ]; then
  # 429 no MEIO do log: e output de teste do projeto, nao limite de uso.
  echo "FAIL tests/HttpClientTest: expected 429 Too Many Requests, got 200"
  for i in $(seq 1 25); do echo "linha de ruido $i"; done
  echo "Suite corrigida. Done."
  exit 0
fi

if [ "$name" = "claude" ]; then emit_claude_ok; else echo "Done."; fi
exit 0
MOCK

  chmod +x "$bin/mock-engine"
  cp "$bin/mock-engine" "$bin/claude"
  cp "$bin/mock-engine" "$bin/codex"
}

make_testcmd() {
  cat > "$1" <<'TESTCMD'
#!/usr/bin/env bash
set -uo pipefail
state="${MOCK_STATE:?}"
scenario="${MOCK_SCENARIO:-ok}"
f="$state/test_calls"; n=0
[ -f "$f" ] && n=$(cat "$f")
n=$((n + 1)); echo "$n" > "$f"

if [ "$scenario" = "test-red-once" ] || [ "$scenario" = "stall-after-red" ]; then
  if [ "$n" -eq 1 ]; then
    echo "1 failing test: ExpectedFooTest"
    exit 1
  fi
fi
echo "all green"
exit 0
TESTCMD
  chmod +x "$1"
}

PHASES_FIXTURE='# Test Project — Project Phases

<!-- inputs: project-description.md@sha256:000000000000 -->

## Overview

Projeto de teste.

## Phase 1: Foundation

- [ ] **Task:** cria o arquivo A
  - **Acceptance criteria:**
    - o arquivo existe
- [ ] **Task:** cria o arquivo B
  - **Acceptance criteria:**
    - o arquivo existe

## Phase 2: Feature

- [ ] **Task:** cria o arquivo C
  - **Acceptance criteria:**
    - o arquivo existe

## Open Questions

- nenhuma
'

# new_case <nome> -> ecoa o diretorio do repo fixture
new_case() {
  local name="$1"
  local dir="$TMP/$name"
  mkdir -p "$dir/repo" "$dir/state" "$dir/bin"
  make_mocks "$dir/bin"
  make_testcmd "$dir/test.sh"

  (
    cd "$dir/repo" || exit 1
    git init -q
    git config user.email "test@ralph"
    git config user.name "Ralph Test"
    mkdir -p .spec/init
    printf '%s' "$PHASES_FIXTURE" > .spec/init/project-phases.md
    git add -A
    git commit -q -m "chore: fixture"
  )
  echo "$dir"
}

# run_ralph <dir> <scenario> [args...] -> ecoa o exit code; log em <dir>/out.log
run_ralph() {
  local dir="$1" scenario="$2"; shift 2
  local rc=0
  (
    cd "$dir/repo" || exit 1
    PATH="$dir/bin:$PATH" \
    MOCK_STATE="$dir/state" \
    MOCK_SCENARIO="$scenario" \
    RALPH_LIMIT_WAIT_DEFAULT=1 \
    RALPH_LIMIT_BUFFER=1 \
      bash "$RALPH" "$@" > "$dir/out.log" 2>&1
  ) || rc=$?
  echo "$rc"
}

commits() { git -C "$1/repo" rev-list --count HEAD; }

case_enabled() { [ -z "$ONLY" ] || [ "$ONLY" = "$1" ]; }

header() { CURRENT="$1"; echo -e "\n${YELLOW}== $1${NC}"; }

# ---------------------------------------------------------------------------
# 1. Fase ok de primeira -> 1 commit por fase, progresso gravado
# ---------------------------------------------------------------------------
if case_enabled ok-first; then
  header "1. fase ok de primeira"
  d=$(new_case ok-first)
  rc=$(run_ralph "$d" ok --engine claude --test-cmd "$d/test.sh")
  assert_eq 0 "$rc" "exit 0"
  assert_eq 3 "$(commits "$d")" "2 commits de fase (1 fixture + 2)"
  assert_contains "$d/repo/.phases/.progress" "phase-01.md" "progresso registra phase-01"
  assert_contains "$d/repo/.phases/.progress" "phase-02.md" "progresso registra phase-02"
  assert_eq "feat(phase-2): Feature" "$(git -C "$d/repo" log -1 --pretty=%s)" "mensagem de commit da ultima fase"
  assert_eq 2 "$(cat "$d/state/impl_calls")" "1 sessao de implementacao por fase (2 fases)"
  assert_eq 2 "$(cat "$d/state/verify_calls")" "1 sessao verificadora por fase"
fi

# ---------------------------------------------------------------------------
# 2. Gate 2 vermelho 1x -> ciclo de correcao -> verde -> 1 commit so
# ---------------------------------------------------------------------------
if case_enabled test-red-once; then
  header "2. gate 2 vermelho uma vez -> ciclo de correcao"
  d=$(new_case test-red-once)
  rc=$(run_ralph "$d" test-red-once --engine claude --test-cmd "$d/test.sh" --max-cycles 2)
  assert_eq 0 "$rc" "exit 0"
  assert_eq 3 "$(commits "$d")" "1 commit por fase (ciclo intermediario nao commita)"
  assert_contains "$d/out.log" "Gate 2 vermelho" "gate 2 reportado vermelho"
  assert_contains "$d/out.log" "Ciclo de correcao 2/2" "entrou em ciclo de correcao"
  # o prompt de correcao carrega a causa REAL, nao "os testes falharam" generico
  assert_contains "$d/repo/.phases/prompts/phase-01.cycle-2.txt" "ExpectedFooTest" "prompt de correcao carrega a saida do teste"
  assert_contains "$d/repo/.phases/prompts/phase-01.cycle-2.txt" "## Fase a completar" "prompt de correcao e auto-contido (fase inteira)"
  # logs por ciclo, nunca sobrescritos
  test -f "$d/repo/.phases/logs/phase-01.cycle-1.log" && test -f "$d/repo/.phases/logs/phase-01.cycle-2.log" \
    && ok "logs por ciclo preservados" || bad "logs por ciclo preservados"
fi

# ---------------------------------------------------------------------------
# 3. Diff vazio -> falha sem commit
# ---------------------------------------------------------------------------
if case_enabled empty-diff; then
  header "3. diff vazio -> falha sem commit"
  d=$(new_case empty-diff)
  rc=$(run_ralph "$d" empty-diff --engine claude --test-cmd "$d/test.sh" --max-cycles 2)
  assert_eq 1 "$rc" "exit 1"
  assert_eq 1 "$(commits "$d")" "nenhum commit criado (sem --allow-empty)"
  assert_contains "$d/out.log" "Gate 1 vermelho" "gate 1 reportado vermelho"
  assert_contains "$d/out.log" "Parando na primeira fase que falhou" "politica default = parar"
  test -f "$d/state/verify_calls" && bad "verificador nao deve rodar apos gate 1" || ok "verificador nao roda apos gate 1"
fi

# ---------------------------------------------------------------------------
# 4. Verificador INCOMPLETE 1x -> ciclo -> DONE -> commit
# ---------------------------------------------------------------------------
if case_enabled verify-incomplete; then
  header "4. verificador INCOMPLETE uma vez -> ciclo -> DONE"
  d=$(new_case verify-incomplete)
  rc=$(run_ralph "$d" verify-incomplete-once --engine claude --test-cmd "$d/test.sh" --max-cycles 2)
  assert_eq 0 "$rc" "exit 0"
  assert_eq 3 "$(commits "$d")" "1 commit por fase"
  assert_contains "$d/out.log" "Gate 3 vermelho" "gate 3 reportado vermelho"
  assert_contains "$d/repo/.phases/prompts/phase-01.cycle-2.txt" "TASK 1: INCOMPLETE" "prompt de correcao carrega as tasks incompletas verbatim"
  test -f "$d/repo/.phases/logs/phase-01.verify-1.log" && ok "log do verificador por ciclo" || bad "log do verificador por ciclo"
fi

# ---------------------------------------------------------------------------
# 5. Limite com epoch -> espera -> re-executa a MESMA fase sem consumir ciclo
# ---------------------------------------------------------------------------
if case_enabled limit-epoch; then
  header "5. limite com epoch -> espera -> mesma fase"
  d=$(new_case limit-epoch)
  # --max-cycles 1: se a espera consumisse um ciclo, a fase falharia
  rc=$(run_ralph "$d" limit-epoch --engine claude --test-cmd "$d/test.sh" --max-cycles 1)
  assert_eq 0 "$rc" "exit 0 (limite nao consome ciclo)"
  assert_eq 3 "$(commits "$d")" "fases commitadas apos a espera"
  assert_contains "$d/out.log" "Limite de uso atingido" "limite detectado"
  assert_contains "$d/out.log" "Reset previsto para" "epoch de reset extraido do log"
fi

# ---------------------------------------------------------------------------
# 6. Limite generico sem epoch -> fallback wait
# ---------------------------------------------------------------------------
if case_enabled limit-generic; then
  header "6. limite generico sem epoch -> fallback"
  d=$(new_case limit-generic)
  rc=$(run_ralph "$d" limit-generic --engine codex --test-cmd "$d/test.sh" --max-cycles 1)
  assert_eq 0 "$rc" "exit 0"
  assert_contains "$d/out.log" "Sem horario de reset no output" "usou o fallback de espera"
  assert_eq 3 "$(commits "$d")" "fases commitadas apos a espera"
fi

# ---------------------------------------------------------------------------
# 7. "429 Too Many Requests" no MEIO do log -> NAO dispara espera (regressao)
# ---------------------------------------------------------------------------
if case_enabled false-429; then
  header "7. 429 no meio do log nao dispara espera"
  d=$(new_case false-429)
  start=$(date +%s)
  rc=$(run_ralph "$d" false-429 --engine codex --test-cmd "$d/test.sh" --max-cycles 1)
  elapsed=$(($(date +%s) - start))
  assert_eq 0 "$rc" "exit 0"
  assert_not_contains "$d/out.log" "Limite de uso atingido" "nao interpretou 429 de teste como limite"
  assert_contains "$d/repo/.phases/logs/phase-01.cycle-1.log" "429 Too Many Requests" "o 429 realmente estava no log"
  [ "$elapsed" -lt 5 ] && ok "sem espera (${elapsed}s)" || bad "sem espera (${elapsed}s)"
fi

# ---------------------------------------------------------------------------
# 8. Segunda execucao com mesmo input -> fases feitas puladas (resume vivo)
# ---------------------------------------------------------------------------
if case_enabled resume; then
  header "8. resume: segunda execucao pula fases feitas"
  d=$(new_case resume)
  rc=$(run_ralph "$d" ok --engine claude --test-cmd "$d/test.sh")
  assert_eq 0 "$rc" "primeira execucao verde"
  before=$(commits "$d")
  rc=$(run_ralph "$d" ok --engine claude --test-cmd "$d/test.sh")
  assert_eq 0 "$rc" "segunda execucao verde"
  assert_eq "$before" "$(commits "$d")" "nenhum commit novo"
  assert_contains "$d/out.log" "Progresso anterior preservado" "progresso preservado (input inalterado)"
  assert_contains "$d/out.log" "(ja completada)" "fases puladas"
fi

# ---------------------------------------------------------------------------
# 9. Input mutado entre execucoes -> progresso invalidado com aviso
# ---------------------------------------------------------------------------
if case_enabled resume-invalidated; then
  header "9. input mutado -> progresso invalidado"
  d=$(new_case resume-invalidated)
  rc=$(run_ralph "$d" ok --engine claude --test-cmd "$d/test.sh")
  assert_eq 0 "$rc" "primeira execucao verde"
  before=$(commits "$d")
  (
    cd "$d/repo" || exit 1
    printf '\n## Phase 3: Extra\n\n- [ ] **Task:** cria o arquivo D\n  - **Acceptance criteria:**\n    - o arquivo existe\n' >> .spec/init/project-phases.md
    git add -A && git commit -q -m "chore: nova fase"
  )
  rc=$(run_ralph "$d" ok --engine claude --test-cmd "$d/test.sh")
  assert_eq 0 "$rc" "segunda execucao verde"
  assert_contains "$d/out.log" "progresso zerado" "progresso invalidado com aviso"
  assert_eq $((before + 4)) "$(commits "$d")" "3 fases re-executadas + commit da mutacao"
fi

# ---------------------------------------------------------------------------
# 10. Arvore suja no preflight -> abort antes de qualquer sessao
# ---------------------------------------------------------------------------
if case_enabled dirty-tree; then
  header "10. arvore suja -> abort no preflight"
  d=$(new_case dirty-tree)
  echo "trabalho nao commitado" > "$d/repo/rascunho.txt"
  rc=$(run_ralph "$d" ok --engine claude --test-cmd "$d/test.sh")
  assert_eq 1 "$rc" "exit 1"
  assert_contains "$d/out.log" "Arvore de trabalho suja" "abortou com instrucao"
  test -f "$d/state/impl_calls" && bad "nenhuma sessao de engine iniciada" || ok "nenhuma sessao de engine iniciada"
fi

# ---------------------------------------------------------------------------
# 11. Contrato de formato do input -> abort antes de gastar token
# ---------------------------------------------------------------------------
if case_enabled bad-format; then
  header "11. heading de fase torto -> abort no preflight"
  d=$(new_case bad-format)
  (
    cd "$d/repo" || exit 1
    sed -i 's/^## Phase 2: Feature$/## Phase Two — Feature/' .spec/init/project-phases.md
    git add -A && git commit -q -m "chore: heading torto"
  )
  rc=$(run_ralph "$d" ok --engine claude --test-cmd "$d/test.sh")
  # "## Phase Two" nao casa com '^## Phase [0-9]+: ' -> heading malformado
  assert_eq 1 "$rc" "exit 1"
  assert_contains "$d/out.log" "Contrato de formato violado" "abortou por formato invalido"
  test -f "$d/state/impl_calls" && bad "nenhuma sessao de engine iniciada" || ok "nenhuma sessao de engine iniciada"
fi

# ---------------------------------------------------------------------------
# 12. Ciclo de correcao que nao escreve nada -> gate 1 vermelho
#     (o diff herdado do ciclo anterior nao pode passar de graca)
# ---------------------------------------------------------------------------
if case_enabled stall-after-red; then
  header "12. ciclo de correcao sem escrever nada -> gate 1 vermelho"
  d=$(new_case stall-after-red)
  rc=$(run_ralph "$d" stall-after-red --engine claude --test-cmd "$d/test.sh" --max-cycles 2)
  assert_eq 1 "$rc" "exit 1"
  assert_eq 1 "$(commits "$d")" "nenhum commit criado"
  assert_contains "$d/out.log" "Gate 1 vermelho" "gate 1 pegou a sessao que nao alterou nada"
  assert_contains "$d/out.log" "Gate 2 vermelho" "o ciclo comecou por um gate 2 vermelho"
fi

# ---------------------------------------------------------------------------
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if [ "$FAIL" -eq 0 ]; then
  echo -e "${GREEN}TODOS VERDES: $PASS asserts${NC}"
else
  echo -e "${RED}FALHAS: $FAIL${NC} / verdes: $PASS"
fi
exit $((FAIL > 0 ? 1 : 0))
