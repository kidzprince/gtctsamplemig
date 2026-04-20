# ============================================================
# AzMigrateDemo - GitHub 초기 설정 및 업로드 가이드
# PowerShell 스크립트
# ============================================================

<#
.SYNOPSIS
    GitHub 리포지토리 생성 및 코드 업로드 가이드

.DESCRIPTION
    이 스크립트를 실행하기 전에:
    1. GitHub 계정이 있어야 합니다
    2. Git이 설치되어 있어야 합니다 (https://git-scm.com)
    3. GitHub CLI(gh) 설치를 권장합니다 (https://cli.github.com)
#>

#region ── STEP 1: Git 설치 확인 ────────────────────────────────

Write-Host "`n[STEP 1] Git 설치 확인" -ForegroundColor Cyan

$git = Get-Command git -ErrorAction SilentlyContinue
if (-not $git) {
    Write-Host "  Git이 설치되어 있지 않습니다." -ForegroundColor Red
    Write-Host "  설치: winget install Git.Git" -ForegroundColor Yellow
    Write-Host "  또는: https://git-scm.com/download/win" -ForegroundColor Yellow
    exit 1
}
Write-Host "  Git 버전: $(git --version)" -ForegroundColor Green

#endregion

#region ── STEP 2: Git 초기 설정 ────────────────────────────────

Write-Host "`n[STEP 2] Git 사용자 정보 설정" -ForegroundColor Cyan

# ⚠️  본인 정보로 변경하세요
$gitUserName  = git config --global user.name
$gitUserEmail = git config --global user.email

if (-not $gitUserName) {
    Write-Host "  Git 사용자 이름을 설정합니다..." -ForegroundColor Yellow
    $name = Read-Host "  GitHub 사용자 이름 입력"
    git config --global user.name $name
}

if (-not $gitUserEmail) {
    Write-Host "  Git 이메일을 설정합니다..." -ForegroundColor Yellow
    $email = Read-Host "  GitHub 이메일 입력"
    git config --global user.email $email
}

Write-Host "  사용자: $(git config --global user.name)" -ForegroundColor Green
Write-Host "  이메일: $(git config --global user.email)" -ForegroundColor Green

# 기본 브랜치를 main으로 설정
git config --global init.defaultBranch main
Write-Host "  기본 브랜치: main" -ForegroundColor Green

#endregion

#region ── STEP 3: 로컬 Git 리포지토리 초기화 ───────────────────

Write-Host "`n[STEP 3] 로컬 Git 리포지토리 초기화" -ForegroundColor Cyan

$projectPath = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectPath = Split-Path -Parent $projectPath  # scripts 상위 폴더
Set-Location $projectPath

Write-Host "  프로젝트 경로: $projectPath" -ForegroundColor Gray

# .git 폴더가 없으면 초기화
if (-not (Test-Path ".git")) {
    git init
    Write-Host "  Git 리포지토리 초기화 완료" -ForegroundColor Green
} else {
    Write-Host "  이미 Git 리포지토리가 존재합니다" -ForegroundColor Yellow
}

#endregion

#region ── STEP 4: .gitignore 확인 및 첫 커밋 ──────────────────

Write-Host "`n[STEP 4] 파일 스테이징 및 커밋" -ForegroundColor Cyan

# .gitignore 확인
if (Test-Path ".gitignore") {
    Write-Host "  .gitignore 존재 확인됨" -ForegroundColor Green
} else {
    Write-Host "  .gitignore 파일이 없습니다!" -ForegroundColor Red
    exit 1
}

# 민감 정보 패턴 사전 검사
Write-Host "  민감 정보 패턴 검사 중..." -ForegroundColor Gray
$sensitivePatterns = @("password\s*=", "connectionstring.*pwd", "api.key\s*=")
$found = $false
Get-ChildItem -Recurse -Include "*.cs","*.java","*.config","*.sql" |
    ForEach-Object {
        $content = Get-Content $_.FullName -Raw -ErrorAction SilentlyContinue
        foreach ($pattern in $sensitivePatterns) {
            if ($content -match $pattern) {
                Write-Host "  ⚠️  주의: $($_.Name) 에 민감 정보 패턴 발견" -ForegroundColor Yellow
                $found = $true
            }
        }
    }
if (-not $found) {
    Write-Host "  민감 정보 패턴 없음 - 안전" -ForegroundColor Green
}

# 파일 스테이징
git add .
Write-Host "`n  스테이징된 파일:" -ForegroundColor Gray
git status --short

# 첫 번째 커밋
git commit -m "feat: Azure Migrate + GitHub Copilot 데모 초기 설정

- SQL Server 재고관리 DB 스키마 (InventoryDB)
- ASP.NET MVC 4.8 웹앱 (IIS)
- Java Servlet REST API (Tomcat)
- 자동 설치 스크립트 (PowerShell)
- GitHub Actions CI 워크플로우
- GitHub Copilot 지침 파일

Azure Migrate 탐지 대상:
  - IIS Web App (.NET)
  - Tomcat Java App
  - SQL Server Database
  - Dependency: IIS → Tomcat → SQL Server"

Write-Host "  첫 번째 커밋 완료" -ForegroundColor Green

#endregion

#region ── STEP 5: GitHub 리포지토리 생성 및 Push ───────────────

Write-Host "`n[STEP 5] GitHub 리포지토리 생성" -ForegroundColor Cyan

$gh = Get-Command gh -ErrorAction SilentlyContinue

if ($gh) {
    # GitHub CLI 사용 (권장)
    Write-Host "  GitHub CLI로 리포지토리 생성..." -ForegroundColor Gray

    $repoName = "AzMigrateDemo"
    $repoDesc = "Azure Migrate + GitHub Copilot 데모 - 재고관리 시스템 (IIS + Tomcat + SQL Server)"

    gh repo create $repoName `
        --description $repoDesc `
        --private `
        --source=. `
        --remote=origin `
        --push

    Write-Host "  GitHub 리포지토리 생성 및 Push 완료!" -ForegroundColor Green
    gh repo view --web

} else {
    # GitHub CLI가 없으면 수동 안내
    Write-Host @"

  GitHub CLI가 설치되어 있지 않습니다.
  아래 방법 중 하나를 선택하세요:

  방법 1: GitHub CLI 설치 후 재실행
    winget install GitHub.cli
    gh auth login
    .\scripts\Setup-GitHub.ps1

  방법 2: 수동으로 GitHub에서 리포지토리 생성
    1. https://github.com/new 접속
    2. Repository name: AzMigrateDemo
    3. Private 선택
    4. README 체크 해제 (이미 있음)
    5. Create repository 클릭
    6. 아래 명령어 실행:

"@ -ForegroundColor Yellow

    $ghUsername = Read-Host "  GitHub 사용자명 입력 (원격 URL 설정용)"
    Write-Host @"

  ─── 복사해서 실행하세요 ───────────────────────────
  git remote add origin https://github.com/$ghUsername/AzMigrateDemo.git
  git branch -M main
  git push -u origin main
  ──────────────────────────────────────────────────

"@ -ForegroundColor White
}

#endregion

#region ── STEP 6: 브랜치 전략 설정 ────────────────────────────

Write-Host "`n[STEP 6] 브랜치 전략 설정" -ForegroundColor Cyan

# develop 브랜치 생성
git checkout -b develop
git push -u origin develop 2>$null
git checkout main

Write-Host @"
  브랜치 구조:
  main    → 안정 버전 (데모 발표용)
  develop → 개발 중인 변경사항
  
  작업 흐름:
  1. develop 브랜치에서 작업
     git checkout develop
     git checkout -b feature/azure-sql-migration
     
  2. 변경 후 develop에 병합
     git checkout develop
     git merge feature/azure-sql-migration
     
  3. 데모 준비 완료 시 main에 병합
     git checkout main
     git merge develop
"@ -ForegroundColor Gray

#endregion

#region ── 완료 요약 ────────────────────────────────────────────

Write-Host "`n" + ("="*55) -ForegroundColor Green
Write-Host "  GitHub 설정 완료!" -ForegroundColor Green
Write-Host ("="*55) -ForegroundColor Green

Write-Host @"

  📁 리포지토리 구조:
  ├── .github/
  │   ├── workflows/ci.yml           ← 자동 검증 CI
  │   ├── copilot-instructions.md    ← Copilot 지침
  │   ├── ISSUE_TEMPLATE/            ← 이슈 템플릿
  │   └── pull_request_template.md   ← PR 템플릿
  ├── sql/                           ← DB 스크립트
  ├── iis-webapp/                    ← ASP.NET 웹앱
  ├── tomcat-api/                    ← Java REST API
  ├── scripts/                       ← 설치 스크립트
  ├── .gitignore                     ← 민감 정보 제외
  └── README.md                      ← 프로젝트 설명

  🤖 GitHub Copilot 활성화 방법:
  1. VS Code에서 리포지토리 열기
  2. GitHub Copilot 확장 설치
  3. .github/copilot-instructions.md 가 자동으로
     Copilot 컨텍스트에 반영됨

  📌 다음 단계:
  1. iis-webapp/InventoryApp.cs 열기
  2. Copilot에게 'Azure SQL로 연결 방식 변경해줘' 요청
  3. Azure Migrate Assessment와 비교하며 데모 진행

"@ -ForegroundColor White

#endregion
