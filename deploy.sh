#!/usr/bin/env bash
# 운동 기록 웹앱을 GitHub Pages로 배포한다.
# 사용: bash deploy.sh            (기본 저장소: simsangun92-jpg/workout-log)
#       REPO=owner/name bash deploy.sh
set -uo pipefail
cd "$(dirname "$0")"

REPO="${REPO:-simsangun92-jpg/workout-log}"
OWNER="${REPO%%/*}"
NAME="${REPO##*/}"
BRANCH="main"
URL="https://${OWNER}.github.io/${NAME}/"

say() { printf '\n== %s\n' "$*"; }

# 0) 저장소 접근 확인
if ! gh api "repos/${REPO}" >/dev/null 2>&1; then
  say "저장소 ${REPO} 에 접근할 수 없습니다. 생성을 시도합니다."
  if ! gh repo create "${NAME}" --public --description "운동 기록 웹앱"; then
    cat >&2 <<'MSG'

[막힘] 이 GitHub 연결에는 저장소 생성 권한이 없습니다 (403 Resource not accessible by integration).

해결 방법 (사람이 한 번만 하면 됩니다):
  1. https://github.com/new 에서
     Repository name: workout-log / Public / README 등 아무것도 추가하지 말고 Create
  2. https://github.com/apps/pickle/installations/new 에서
     계정 선택 → Only select repositories → workout-log 선택 → Install
  3. 다시 실행: bash deploy.sh
MSG
    exit 2
  fi
fi

# 1) 커밋
say "커밋 준비"
git init -q 2>/dev/null || true
git symbolic-ref HEAD "refs/heads/${BRANCH}" 2>/dev/null || true
git config user.name "simsangun92-jpg"
git config user.email "360582510+simsangun92-jpg@users.noreply.github.com"
git add -A
if ! git diff --cached --quiet; then
  git commit -q -m "운동 기록 웹앱: 루틴/코치 메모 실시간 연동, PWA 지원"
fi
git remote remove origin 2>/dev/null || true
git remote add origin "https://github.com/${REPO}.git"

# 2) 푸시
say "푸시 → ${REPO} (${BRANCH})"
if ! git push -u origin "${BRANCH}" --force 2>&1; then
  echo "[막힘] 푸시가 거절되었습니다. 위 메시지의 권한 사유를 확인하세요." >&2
  exit 3
fi

# 3) Pages 활성화 (main / root)
say "GitHub Pages 활성화"
if gh api "repos/${REPO}/pages" >/dev/null 2>&1; then
  gh api -X PUT "repos/${REPO}/pages" -f "source[branch]=${BRANCH}" -f "source[path]=/" >/dev/null 2>&1 \
    || echo "  (이미 활성화되어 있거나 설정 변경 권한이 없습니다)"
else
  if ! gh api -X POST "repos/${REPO}/pages" -f "source[branch]=${BRANCH}" -f "source[path]=/" >/dev/null 2>&1; then
    echo "[막힘] Pages 활성화 요청이 거부되었습니다. 저장소 Settings → Pages 에서
       Source: Deploy from a branch / Branch: ${BRANCH} / folder: / (root) 를 직접 선택하세요." >&2
    exit 4
  fi
fi

# 4) HTTP 200 확인 (최대 5분)
say "확인: ${URL}"
for i in $(seq 1 30); do
  code=$(curl -s -o /dev/null -w '%{http_code}' -L "${URL}" || echo 000)
  if [ "${code}" = "200" ]; then
    echo "index.html  HTTP ${code}"
    break
  fi
  echo "  시도 ${i}: HTTP ${code} (Pages 빌드 대기)"
  sleep 10
done
for path in program.json manifest.json sw.js icon-192.png; do
  code=$(curl -s -o /dev/null -w '%{http_code}' -L "${URL}${path}" || echo 000)
  echo "${path}  HTTP ${code}"
done
say "끝. 휴대폰에서 ${URL} 를 열고 '홈 화면에 추가'를 누르세요."
