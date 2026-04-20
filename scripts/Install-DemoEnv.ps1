#Requires -RunAsAdministrator
<#
.SYNOPSIS
    AzMigrateDemo - Windows 데모 환경 자동 설치 스크립트
    
.DESCRIPTION
    Azure Migrate + GitHub Copilot 데모용 환경 구성:
    1. IIS + ASP.NET 역할 설치
    2. SQL Server Express 다운로드 및 설치
    3. Java JDK 설치
    4. Apache Tomcat 설치
    5. DB 스키마 및 샘플 데이터 생성
    6. 서비스 간 연결 구성 (Dependency Analysis 시각화용)

.NOTES
    ⚠️  실행 전 확인사항:
    - Windows Server 2019/2022 또는 Windows 10/11
    - 관리자 권한으로 PowerShell 실행
    - 인터넷 연결 필요 (패키지 다운로드)
    - 최소 20GB 여유 디스크 공간
#>

param(
    [string]$InstallPath = "C:\AzMigrateDemo",
    [string]$SqlInstance = "SQLEXPRESS",
    [switch]$SkipSqlInstall,
    [switch]$SkipJavaInstall
)

#region ── 초기화 ────────────────────────────────────────────────

$ErrorActionPreference = "Stop"
$ProgressPreference    = "SilentlyContinue"

function Write-Step {
    param([string]$Msg)
    Write-Host "`n[STEP] $Msg" -ForegroundColor Cyan
}
function Write-OK   { param([string]$Msg) Write-Host "  [OK]  $Msg" -ForegroundColor Green  }
function Write-Warn { param([string]$Msg) Write-Host "  [!!]  $Msg" -ForegroundColor Yellow }
function Write-Fail { param([string]$Msg) Write-Host "  [ERR] $Msg" -ForegroundColor Red    }

New-Item -ItemType Directory -Force -Path $InstallPath | Out-Null
New-Item -ItemType Directory -Force -Path "$InstallPath\logs" | Out-Null

$LogFile = "$InstallPath\logs\install_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
Start-Transcript -Path $LogFile

#endregion

#region ── STEP 1: IIS + ASP.NET 설치 ──────────────────────────

Write-Step "IIS + ASP.NET 4.8 역할 설치"

$features = @(
    "Web-Server",
    "Web-WebServer",
    "Web-Common-Http",
    "Web-Default-Doc",
    "Web-Dir-Browsing",
    "Web-Http-Errors",
    "Web-Static-Content",
    "Web-Http-Redirect",
    "Web-Health",
    "Web-Http-Logging",
    "Web-Performance",
    "Web-Stat-Compression",
    "Web-Security",
    "Web-Filtering",
    "Web-App-Dev",
    "Web-Asp-Net45",
    "Web-Net-Ext45",
    "Web-ISAPI-Ext",
    "Web-ISAPI-Filter",
    "Web-Mgmt-Tools",
    "Web-Mgmt-Console"
)

foreach ($feature in $features) {
    $result = Install-WindowsFeature -Name $feature -IncludeManagementTools -ErrorAction SilentlyContinue
    if ($result.Success) {
        Write-OK "$feature 설치 완료"
    } else {
        Write-Warn "$feature 이미 설치됨 또는 건너뜀"
    }
}

# IIS 기본 사이트 포트 확인
Write-OK "IIS 설치 완료 - http://localhost 접속 가능"

#endregion

#region ── STEP 2: SQL Server Express 설치 ──────────────────────

Write-Step "SQL Server 2019 Express 설치"

if ($SkipSqlInstall) {
    Write-Warn "SQL Server 설치 건너뜀 (-SkipSqlInstall)"
} else {
    $sqlInstallerUrl = "https://go.microsoft.com/fwlink/?linkid=866658"  # SQL Server 2019 Express
    $sqlInstaller    = "$InstallPath\SQL2019Express.exe"

    if (-not (Test-Path $sqlInstaller)) {
        Write-Host "  SQL Server Express 다운로드 중..." -ForegroundColor Gray
        Invoke-WebRequest -Uri $sqlInstallerUrl -OutFile $sqlInstaller
    }

    Write-Host "  SQL Server Express 설치 중 (약 3~5분)..." -ForegroundColor Gray
    $args = @(
        "/Q",
        "/ACTION=Install",
        "/FEATURES=SQLEngine",
        "/INSTANCENAME=$SqlInstance",
        "/SQLSYSADMINACCOUNTS=BUILTIN\Administrators",
        "/TCPENABLED=1",
        "/NPENABLED=1",
        "/IACCEPTSQLSERVERLICENSETERMS"
    )
    Start-Process -FilePath $sqlInstaller -ArgumentList $args -Wait -NoNewWindow

    # SQL Server Browser 서비스 시작
    Set-Service -Name "SQLBrowser" -StartupType Automatic -ErrorAction SilentlyContinue
    Start-Service -Name "SQLBrowser" -ErrorAction SilentlyContinue

    Write-OK "SQL Server Express 설치 완료 - Instance: .\$SqlInstance"
}

#endregion

#region ── STEP 3: DB 스키마 및 샘플 데이터 생성 ────────────────

Write-Step "InventoryDB 생성 및 샘플 데이터 입력"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

# SQL 스크립트 파일 위치 확인
$schemaScript  = "$scriptDir\sql\01_schema.sql"
$dataScript    = "$scriptDir\sql\02_sampledata.sql"

if (-not (Test-Path $schemaScript)) {
    # 스크립트가 없으면 현재 디렉토리에서 찾기
    $schemaScript  = ".\sql\01_schema.sql"
    $dataScript    = ".\sql\02_sampledata.sql"
}

try {
    $sqlParams = @{
        ServerInstance = "localhost\$SqlInstance"
        InputFile      = $schemaScript
        ErrorAction    = "Stop"
    }
    Invoke-Sqlcmd @sqlParams
    Write-OK "스키마 생성 완료"

    $sqlParams.InputFile = $dataScript
    Invoke-Sqlcmd @sqlParams
    Write-OK "샘플 데이터 입력 완료"

    # 확인
    $count = Invoke-Sqlcmd -ServerInstance "localhost\$SqlInstance" `
                           -Database InventoryDB `
                           -Query "SELECT COUNT(*) AS cnt FROM Products"
    Write-OK "Products 테이블: $($count.cnt)개 레코드 입력됨"

} catch {
    Write-Fail "DB 생성 실패: $_"
    Write-Warn "수동으로 SSMS에서 sql\ 폴더의 SQL 파일을 실행하세요"
}

#endregion

#region ── STEP 4: Java JDK 설치 ────────────────────────────────

Write-Step "OpenJDK 17 설치 (Tomcat 실행용)"

if ($SkipJavaInstall) {
    Write-Warn "Java 설치 건너뜀 (-SkipJavaInstall)"
} else {
    # Winget으로 설치 시도
    $winget = Get-Command winget -ErrorAction SilentlyContinue
    if ($winget) {
        winget install Microsoft.OpenJDK.17 --silent --accept-package-agreements --accept-source-agreements
        Write-OK "OpenJDK 17 설치 완료 (Winget)"
    } else {
        # 수동 다운로드
        $jdkUrl = "https://aka.ms/download-jdk/microsoft-jdk-17-windows-x64.msi"
        $jdkMsi = "$InstallPath\openjdk17.msi"
        Write-Host "  OpenJDK 17 다운로드 중..." -ForegroundColor Gray
        Invoke-WebRequest -Uri $jdkUrl -OutFile $jdkMsi
        Start-Process msiexec.exe -ArgumentList "/i `"$jdkMsi`" /quiet /norestart ADDLOCAL=ALL" -Wait
        Write-OK "OpenJDK 17 설치 완료"
    }

    # JAVA_HOME 환경 변수 설정
    $javaHome = "C:\Program Files\Microsoft\jdk-17*" | Resolve-Path -ErrorAction SilentlyContinue
    if ($javaHome) {
        [System.Environment]::SetEnvironmentVariable("JAVA_HOME", $javaHome.Path, "Machine")
        Write-OK "JAVA_HOME 설정: $($javaHome.Path)"
    }
}

#endregion

#region ── STEP 5: Apache Tomcat 설치 ───────────────────────────

Write-Step "Apache Tomcat 10.1 설치"

$tomcatVersion = "10.1.28"
$tomcatUrl     = "https://dlcdn.apache.org/tomcat/tomcat-10/v$tomcatVersion/bin/apache-tomcat-$tomcatVersion-windows-x64.zip"
$tomcatZip     = "$InstallPath\tomcat.zip"
$tomcatHome    = "C:\tomcat"

if (-not (Test-Path $tomcatHome)) {
    Write-Host "  Tomcat $tomcatVersion 다운로드 중..." -ForegroundColor Gray
    try {
        Invoke-WebRequest -Uri $tomcatUrl -OutFile $tomcatZip
        Expand-Archive -Path $tomcatZip -DestinationPath "C:\"
        Rename-Item "C:\apache-tomcat-$tomcatVersion" $tomcatHome -ErrorAction SilentlyContinue
        Write-OK "Tomcat 압축 해제 완료: $tomcatHome"
    } catch {
        Write-Warn "Tomcat 다운로드 실패. 수동 설치 필요: https://tomcat.apache.org"
    }
}

# Tomcat을 Windows 서비스로 등록
$serviceBat = "$tomcatHome\bin\service.bat"
if (Test-Path $serviceBat) {
    & cmd /c "`"$serviceBat`" install Tomcat10" 2>&1 | Out-Null
    Set-Service -Name "Tomcat10" -StartupType Automatic -ErrorAction SilentlyContinue
    Start-Service -Name "Tomcat10" -ErrorAction SilentlyContinue
    Write-OK "Tomcat 서비스 등록 및 시작 완료 - http://localhost:8080"
}

# Tomcat server.xml 포트 확인 (기본 8080)
Write-OK "Tomcat REST API: http://localhost:8080/api/products"

#endregion

#region ── STEP 6: IIS 웹앱 배포 ────────────────────────────────

Write-Step "IIS 웹앱 (재고관리 시스템) 배포"

$webRoot = "C:\inetpub\wwwroot\InventoryApp"
New-Item -ItemType Directory -Force -Path $webRoot | Out-Null

# Web.config 복사
$webConfig = "$scriptDir\iis-webapp\Web.config"
if (Test-Path $webConfig) {
    Copy-Item $webConfig "$webRoot\Web.config" -Force
    # Connection String에서 SQL Instance 업데이트
    $content = Get-Content "$webRoot\Web.config" -Raw
    $content = $content -replace "Data Source=localhost", "Data Source=localhost\$SqlInstance"
    Set-Content "$webRoot\Web.config" $content
    Write-OK "Web.config 배포 완료"
}

# IIS 애플리케이션 풀 생성
Import-Module WebAdministration -ErrorAction SilentlyContinue
if (Get-Module WebAdministration) {
    if (-not (Test-Path "IIS:\AppPools\InventoryAppPool")) {
        New-WebAppPool -Name "InventoryAppPool"
        Set-ItemProperty "IIS:\AppPools\InventoryAppPool" managedRuntimeVersion v4.0
        Write-OK "IIS Application Pool 'InventoryAppPool' 생성"
    }

    if (-not (Test-Path "IIS:\Sites\InventoryApp")) {
        New-WebSite -Name "InventoryApp" -Port 80 -PhysicalPath $webRoot `
                    -ApplicationPool "InventoryAppPool" -Force
        Write-OK "IIS Site 'InventoryApp' 생성 - http://localhost"
    }
}

#endregion

#region ── STEP 7: 방화벽 규칙 설정 ─────────────────────────────

Write-Step "방화벽 규칙 설정 (Azure Migrate Discovery용)"

$rules = @(
    @{ Name="AzMigrate-HTTP";    Port=80;   Protocol="TCP"; Desc="IIS 웹앱" }
    @{ Name="AzMigrate-Tomcat";  Port=8080; Protocol="TCP"; Desc="Tomcat API" }
    @{ Name="AzMigrate-HTTPS";   Port=443;  Protocol="TCP"; Desc="HTTPS" }
    @{ Name="AzMigrate-SQL";     Port=1433; Protocol="TCP"; Desc="SQL Server" }
    @{ Name="AzMigrate-WinRM-H"; Port=5985; Protocol="TCP"; Desc="WinRM HTTP (Azure Migrate)" }
)

foreach ($rule in $rules) {
    New-NetFirewallRule -DisplayName $rule.Name `
        -Direction Inbound -Protocol $rule.Protocol `
        -LocalPort $rule.Port -Action Allow `
        -ErrorAction SilentlyContinue | Out-Null
    Write-OK "방화벽 포트 $($rule.Port) ($($rule.Desc)) 허용"
}

# WinRM 활성화 (Azure Migrate Discovery 필수)
Enable-PSRemoting -Force -ErrorAction SilentlyContinue
Write-OK "WinRM 활성화 완료"

#endregion

#region ── 최종 결과 출력 ────────────────────────────────────────

Write-Host "`n" + ("="*60) -ForegroundColor Green
Write-Host "  AzMigrateDemo 설치 완료!" -ForegroundColor Green
Write-Host ("="*60) -ForegroundColor Green

Write-Host @"

  📦 설치된 구성요소:
  ┌─────────────────────────────────────────────────┐
  │  IIS 웹앱   → http://localhost (포트 80)         │
  │  Tomcat API → http://localhost:8080/api/products │
  │  SQL Server → localhost\$SqlInstance (포트 1433) │
  │  Database   → InventoryDB                        │
  └─────────────────────────────────────────────────┘

  🔗 Dependency Map에서 확인되는 연결:
     IIS (포트 80) ──▶ Tomcat (포트 8080)
     IIS (포트 80) ──▶ SQL Server (포트 1433)
     Tomcat        ──▶ SQL Server (포트 1433)

  🧪 Azure Migrate 동작 확인:
     1. Appliance Configuration Manager에서
        이 서버 자격증명 추가
     2. 24시간 후 Dependency Analysis 확인
     3. Web apps 탭에서 IIS + Tomcat 탐지 확인
     4. Databases 탭에서 SQL Server 탐지 확인

  📋 GitHub Copilot 데모 포인트:
     - InventoryApp.cs → Azure App Service 이전 코드 변환
     - Web.config ConnectionString → Azure SQL로 변경
     - sp_StockIn/Out → Azure Functions로 현대화

  📄 설치 로그: $LogFile

"@ -ForegroundColor White

Stop-Transcript

#endregion
