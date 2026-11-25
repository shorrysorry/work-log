#!/usr/bin/env bash
# 커밋 대상 파일에서 민감정보 패턴을 찾는다. 하나라도 걸리면 실패(exit 1).
# 공통 패턴은 이 파일에, 이름 목록은 로컬 전용 .denylist에 둔다.
set -uo pipefail
cd "$(git rev-parse --show-toplevel)"
files=$(git diff --cached --name-only --diff-filter=ACM | grep -vE '^(scripts/check-sensitive\.sh|\.githooks/)' || true)
[ "${1:-}" = "--all" ] && files=$(git ls-files | grep -vE '^(scripts/check-sensitive\.sh|\.githooks/)')
[ -z "$files" ] && exit 0
common=(
  '[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}'          # 이메일
  '\b[A-Z]{2,}-[0-9]+\b'                                    # 티켓 번호 (CHG-123 등)
  'https?://(?!github\.com/shorrysorry|img\.shields\.io|skillicons\.dev)[^ )>"]+'  # 허용 외 URL
  '\b(apps|packages|src)/[A-Za-z0-9_./-]+'                  # 코드 경로
  '\b(?!(?:Next|Node|Nuxt|Vue|Nest|Three|Express|Chart|Deno|Bun)\.js\b)[A-Za-z0-9_-]+\.(tsx?|jsx?|mjs|scss|css|json|ya?ml)\b' # 소스 파일명 (공개 기술명 제외)
  '\b([0-9]{1,3}\.){3}[0-9]{1,3}\b'                         # IP
  '(notion\.(so|site|com)|slack\.com|gitlab|sentry\.io|grafana)' # 내부 도구 링크
)
fail=0
match() { perl -ne "BEGIN{\$p=shift} print \"\$.: \$_\" if /\$p/$2" "$1" "$3"; }
for f in $files; do
  [ -f "$f" ] || continue
  for p in "${common[@]}"; do
    if match "$p" "" "$f" >/tmp/.cs.$$ && [ -s /tmp/.cs.$$ ]; then echo "✗ [$p] $f"; sed 's/^/    /' /tmp/.cs.$$; fail=1; fi
  done
  if [ -f .denylist ]; then
    while IFS= read -r w; do
      [[ -z "$w" || "$w" == \#* ]] && continue
      if match "$w" "i" "$f" >/tmp/.cs.$$ && [ -s /tmp/.cs.$$ ]; then echo "✗ [금지어] $f"; sed 's/^/    /' /tmp/.cs.$$; fail=1; fi
    done < .denylist
  else
    echo "⚠️  .denylist 없음 — 이름 목록 검사를 건너뜀"; fail=1
  fi
done
rm -f /tmp/.cs.$$
[ $fail -eq 0 ] && echo "✓ 민감정보 검사 통과" || echo "→ 위 항목을 일반화한 뒤 다시 커밋하세요."
exit $fail
