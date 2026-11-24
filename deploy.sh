#!/usr/bin/env bash
# 운동 기록 웹앱을 GitHub Pages로 배포한다.
# 사용: bash deploy.sh                      (기본 저장소: simsangun92-jpg/workout-log)
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

[막힘] 이 GitHub 연결에는 저장소 생성 권한이 없습니다 (403: Resource not accessible by integration).

사람이 한 번만 해두면 되는 일:
  1. https://github.com/new 에서
     Repository name: workout-log / Public / 아무 파일도 추가하지 말고 Create repository
  2. https://github.com/apps/pickle/installations/new 에서
     계정 선택 → Only select repositories → workout-log 체크 → Install
  3. 다시 실행:  bash deploy.sh

MSG
    exit 2
  fi
fi

# 1) 커밋
say "커밋"
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
if ! git push -u origin "${BRANCH}" --force; then
  echo "[막힘] 푸시가 거절되었습니다. 위 사유를 확인하세요." >&2
  exit 3
fi

# 3) Pages 활성화 — ① 브랜치 방식(API)
say "GitHub Pages 활성화 (main / root)"
ENABLED=0
if gh api "repos/${REPO}/pages" >/dev/null 2>&1; then
  if gh api -X PUT "repos/${REPO}/pages" -f "source[branch]=${BRANCH}" -f "source[path]=/" >/dev/null 2>&1; then
    ENABLED=1
  fi
elif gh api -X POST "repos/${REPO}/pages" -f "source[branch]=${BRANCH}" -f "source[path]=/" >/dev/null 2>&1; then
  ENABLED=1
fi

# ② API가 거부되면 GitHub Actions 로 배포 (워크플로 토큰은 pages:write 권한을 가짐)
if [ "${ENABLED}" -eq 0 ]; then
  say "API로 Pages를 켤 수 없어 GitHub Actions 배포로 전환합니다."
  mkdir -p .github/workflows
  cat > .github/workflows/pages.yml <<'YAML'
name: Deploy Pages
on:
  push:
    branches: [main]
  workflow_dispatch:
permissions:
  contents: read
  pages: write
  id-token: write
concurrency:
  group: pages
  cancel-in-progress: true
jobs:
  deploy:
    runs-on: ubuntu-latest
    environment:
      name: github-pages
      url: ${{ steps.deployment.outputs.page_url }}
    steps:
      - uses: actions/checkout@v4
      - uses: actions/configure-pages@v5
        with:
          enablement: true
      - uses: actions/upload-pages-artifact@v3
        with:
          path: .
      - id: deployment
        uses: actions/deploy-pages@v4
YAML
  git add -A
  if ! git diff --cached --quiet; then
    git commit -q -m "Pages 배포 워크플로 추가"
  fi
  if ! git push origin "${BRANCH}"; then
    echo "[막힘] 워크플로 파일 포함 푸시가 거절되었습니다(워크플로 쓰기 권한 없음).
       저장소 Settings → Pages 에서 Source: Deploy from a branch / ${BRANCH} / / (root) 를 직접 선택하세요." >&2
    exit 4
  fi
fi

# 4) HTTP 200 확인 (최대 5분)
say "확인: ${URL}"
for i in $(seq 1 30); do
  code=$(curl -s -o /dev/null -w '%{http_code}' -L "${URL}" || echo 000)
  if [ "${code}" = "200" ]; then
    echo "index.html  HTTP 200"
    break
  fi
  echo "  시도 ${i}: HTTP ${code} (Pages 빌드 대기)"
  sleep 10
done
for path in program.json manifest.json sw.js icon-192.png; do
  code=$(curl -s -o /dev/null -w '%{http_code}' -L "${URL}${path}" || echo 000)
  echo "${path}  HTTP ${code}"
done
say "끝. 휴대폰에서 ${URL} 를 열고 '홈 화면에 추가'를 누르면 됩니다."
