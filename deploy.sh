#!/usr/bin/env bash
# 운동 기록 웹앱을 GitHub Pages에 다시 올린다. (루틴/코치 메모 수정 후 실행)
# 사용: bash deploy.sh                      (기본 저장소: simsangun92-jpg/Workout-log)
#       REPO=owner/name bash deploy.sh
set -uo pipefail
cd "$(dirname "$0")"

REPO="${REPO:-simsangun92-jpg/Workout-log}"
OWNER="${REPO%%/*}"
NAME="${REPO##*/}"
BRANCH="main"
URL="https://${OWNER}.github.io/${NAME}/"

say() { printf '\n== %s\n' "$*"; }

# 0) 저장소 접근 확인
if ! gh api "repos/${REPO}" >/dev/null 2>&1; then
  cat >&2 <<MSG
[막힘] 저장소 ${REPO} 에 접근할 수 없습니다.
  · 저장소가 없으면 github.com/new 에서 Public 으로 만들고
  · github.com/apps/pickle/installations/new 에서 그 저장소를 설치에 추가하세요.
MSG
  exit 2
fi

# 1) 커밋
say "커밋"
git init -q 2>/dev/null || true
git symbolic-ref HEAD "refs/heads/${BRANCH}" 2>/dev/null || true
git config user.name "simsangun92-jpg"
git config user.email "360582510+simsangun92-jpg@users.noreply.github.com"
git add -A
if ! git diff --cached --quiet; then
  git commit -q -m "${1:-운동 기록 웹앱 업데이트}"
fi
git remote remove origin 2>/dev/null || true
git remote add origin "https://github.com/${REPO}.git"

# 2) 푸시 (Pages는 main 푸시만으로 다시 빌드된다)
say "푸시 → ${REPO} (${BRANCH})"
if ! git push -u origin "${BRANCH}"; then
  echo "[막힘] 푸시가 거절되었습니다. 위 사유를 확인하세요." >&2
  exit 3
fi

# 3) Pages 상태 — 켜는 것은 이 연결에 권한이 없어 저장소 설정에서 해야 한다(1회).
if ! gh api "repos/${REPO}/pages" >/dev/null 2>&1; then
  cat >&2 <<'MSG'

[필요] GitHub Pages 가 아직 꺼져 있습니다. Pickle의 GitHub 연결에는 Pages 권한이 없어 API로 켤 수 없습니다.
  저장소 → Settings → Pages → Source: Deploy from a branch → Branch: main, 폴더: /(root) → Save
  (한 번만 하면 되고, 이후에는 이 스크립트의 푸시만으로 갱신됩니다.)
MSG
  exit 4
fi

# 4) HTTP 200 확인 (최대 3분)
say "확인: ${URL}"
for i in $(seq 1 18); do
  code=$(curl -s -o /dev/null -w '%{http_code}' -L "${URL}" || echo 000)
  [ "${code}" = "200" ] && break
  sleep 10
done
for path in "" program.json manifest.json sw.js; do
  code=$(curl -s -o /dev/null -w '%{http_code}' -L "${URL}${path}" || echo 000)
  echo "  /${path}  HTTP ${code}"
done
say "끝: ${URL}"
