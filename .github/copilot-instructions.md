# GitHub Copilot 지침 — AzMigrateDemo

이 파일은 GitHub Copilot이 이 프로젝트의 컨텍스트를 이해하고
더 정확한 코드 제안을 하도록 돕는 지침입니다.

## 프로젝트 개요

**목적**: Azure Migrate + GitHub Copilot을 활용한 온프레미스 → Azure 이전 데모
**구성**: ASP.NET MVC 4.8 (IIS) + Java Servlet (Tomcat) + SQL Server

## 핵심 이전 목표 (Copilot 제안 방향)

### 1. 데이터베이스 연결
```csharp
// ❌ 현재 (온프레미스 - 변경 대상)
var conn = new SqlConnection("Data Source=localhost\\SQLEXPRESS;...");

// ✅ 목표 (Azure SQL + Managed Identity)
// Azure SQL Database + DefaultAzureCredential 사용
// 연결 문자열을 Azure Key Vault 또는 App Configuration에서 가져오기
```

### 2. 설정 관리
```csharp
// ❌ 현재 (Web.config - 변경 대상)
ConfigurationManager.AppSettings["ApiEndpoint"]

// ✅ 목표 (Azure App Configuration)
// IConfiguration + Azure App Configuration Provider 사용
// Feature Flag는 Azure App Configuration Feature Management 활용
```

### 3. 저장 프로시저 → Azure Functions
```csharp
// ❌ 현재 (SQL Server 저장 프로시저)
// sp_StockIn, sp_StockOut

// ✅ 목표 (Azure Functions)
// [FunctionName("StockIn")] HttpTrigger
// [FunctionName("StockOut")] HttpTrigger
// Managed Identity로 Azure SQL 접근
```

### 4. 세션 상태
```csharp
// ❌ 현재 (InProc Session - 변경 대상)
// <sessionState mode="InProc" .../>

// ✅ 목표 (Azure Cache for Redis)
// services.AddStackExchangeRedisCache(...)
// Azure Cache for Redis 연결
```

## 코딩 컨벤션

- **언어**: C# (.NET), Java (Servlet → Spring Boot 이전 고려)
- **인증**: 항상 Managed Identity 우선 (`DefaultAzureCredential`)
- **비밀**: Key Vault 참조, 하드코딩 절대 금지
- **로깅**: `ILogger<T>` 사용 (Application Insights 연동 고려)
- **오류 처리**: try-catch + 구체적인 예외 메시지

## Azure 이전 타겟 서비스

| 현재 | Azure 타겟 |
|------|-----------|
| IIS + ASP.NET 4.8 | Azure App Service (.NET 8) |
| SQL Server Express | Azure SQL Database |
| Tomcat Java Servlet | Azure App Service (Java) 또는 AKS |
| Web.config | Azure App Configuration |
| 로컬 파일 로그 | Azure Monitor + Application Insights |
| 세션 InProc | Azure Cache for Redis |

## 주의사항

1. `System.Web` 네임스페이스 → `Microsoft.AspNetCore` 로 대체 제안
2. `ConfigurationManager` → `IConfiguration` 으로 대체 제안
3. ADO.NET 직접 사용 → Entity Framework Core 또는 Dapper 제안
4. SQL Server 전용 기능 → Azure SQL 호환 여부 확인 후 제안
