# AzMigrateDemo — Azure Migrate + GitHub Copilot 데모 패키지

> **Windows Server 기반 3-Tier 재고관리 시스템**  
> Azure Migrate 탐지 및 GitHub Copilot 마이그레이션 데모용

---

## 📦 구성 요소

```
AzMigrateDemo/
├── sql/
│   ├── 01_schema.sql        ← DB 스키마 (테이블, 뷰, 프로시저)
│   └── 02_sampledata.sql    ← 샘플 데이터 (제품 20개, 입출고 이력, 주문)
├── iis-webapp/
│   ├── Web.config           ← IIS ASP.NET MVC 설정
│   └── InventoryApp.cs      ← 컨트롤러 + 모델 + Repository
├── tomcat-api/
│   └── InventoryApiServlet.java  ← Java REST API (Dependency Map 연결용)
├── scripts/
│   └── Install-DemoEnv.ps1  ← 자동 설치 스크립트
└── README.md
```

---

## 🚀 빠른 시작

### 1단계: 자동 설치
```powershell
# 관리자 권한 PowerShell
cd AzMigrateDemo
.\scripts\Install-DemoEnv.ps1

# SQL Server가 이미 있는 경우
.\scripts\Install-DemoEnv.ps1 -SkipSqlInstall

# Java가 이미 있는 경우
.\scripts\Install-DemoEnv.ps1 -SkipJavaInstall
```

### 2단계: DB 수동 설치 (SSMS 사용 시)
```
1. SSMS 열기
2. sql\01_schema.sql 실행
3. sql\02_sampledata.sql 실행
```

### 3단계: 서비스 확인
```
IIS 웹앱:   http://localhost
Tomcat API: http://localhost:8080/api/products
            http://localhost:8080/api/dashboard
SQL Server: localhost\SQLEXPRESS → InventoryDB
```

---

## 🔍 Azure Migrate에서 탐지되는 항목

| 메뉴 | 탐지 내용 |
|------|----------|
| **Infrastructure** | Windows Server 1대, CPU/메모리/디스크 |
| **Databases** | SQL Server Express, InventoryDB |
| **Web apps** | IIS (.NET 4.8 앱), Tomcat (Java 앱) |
| **Dependency Analysis** | IIS→SQL, Tomcat→SQL, IIS→Tomcat 연결선 |
| **Software** | SQL Server, Java JDK, Apache Tomcat |

---

## 🤖 GitHub Copilot 데모 시나리오

### 시나리오 1: Connection String 현대화
```csharp
// 현재 (Web.config - 온프레미스)
"Data Source=localhost\SQLEXPRESS;..."

// Copilot 제안 후 (Azure SQL + Managed Identity)
"Server=tcp:<server>.database.windows.net,1433;
 Authentication=Active Directory Managed Identity;"
```

### 시나리오 2: ADO.NET → Entity Framework Core
```csharp
// 현재: SqlConnection + SqlCommand 직접 사용
// Copilot 입력: "// TODO: EF Core로 변환"
// Copilot 제안: DbContext + LINQ 코드 자동 생성
```

### 시나리오 3: 하드코딩 설정 → Azure App Configuration
```csharp
// 현재 (Web.config appSettings)
ConfigurationManager.AppSettings["ApiEndpoint"]

// Copilot 제안 후
builder.Configuration.AddAzureAppConfiguration(...)
```

### 시나리오 4: 저장 프로시저 → Azure Functions
```
sp_StockIn  → HTTP Trigger Azure Function
sp_StockOut → HTTP Trigger Azure Function
→ Copilot이 SQL 프로시저 로직을 Function 코드로 변환
```

---

## 📊 데이터 현황

| 테이블 | 레코드 수 | 설명 |
|--------|---------|------|
| Categories | 5 | 전자제품, 사무용품, 네트워크, 소모품, 가구 |
| Suppliers | 5 | 삼성, LG, HP, 시스코, 교보 |
| Products | 20 | 각 카테고리별 4~5개 제품 |
| StockHistory | 24 | 3개월치 입출고 이력 |
| Orders | 5 | 다양한 Status의 주문 |
| OrderDetails | 10 | 주문 상세 |

---

## 🌐 Dependency Analysis 시각화

```
┌─────────────────────────────────────────────┐
│          Dependency Map                      │
│                                              │
│  [IIS :80]  ──포트 8080──▶  [Tomcat :8080]  │
│      │                           │           │
│      └──────포트 1433──────────▶ │           │
│                                  │           │
│                      [SQL Server :1433]◀─────┘
└─────────────────────────────────────────────┘
```
→ Azure Migrate Dependency Analysis에서 위 연결 구조가 자동 시각화됨

---

## ⚠️ 주의사항

- SQL Server Express: 10GB DB 크기 제한 (데모용으로 충분)
- Tomcat: 포트 8080, IIS가 80을 사용하므로 충돌 없음
- WinRM: Azure Migrate Discovery를 위해 5985 포트 열림
- 보안: 데모 환경 전용, 프로덕션 사용 금지
