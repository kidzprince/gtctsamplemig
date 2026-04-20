-- ============================================================
-- AzMigrateDemo - 재고관리 시스템 스키마
-- Azure Migrate + GitHub Copilot 데모용 샘플 DB
-- SQL Server 2019 Developer Edition 기준
-- ============================================================

USE master;
GO

IF EXISTS (SELECT name FROM sys.databases WHERE name = 'InventoryDB')
    DROP DATABASE InventoryDB;
GO

CREATE DATABASE InventoryDB
    COLLATE Korean_Wansung_CI_AS;
GO

USE InventoryDB;
GO

-- ── 카테고리 테이블 ──────────────────────────────────────────
CREATE TABLE Categories (
    CategoryId   INT           IDENTITY(1,1) PRIMARY KEY,
    CategoryName NVARCHAR(100) NOT NULL,
    Description  NVARCHAR(500),
    CreatedAt    DATETIME2     DEFAULT GETDATE()
);

-- ── 공급업체 테이블 ──────────────────────────────────────────
CREATE TABLE Suppliers (
    SupplierId   INT           IDENTITY(1,1) PRIMARY KEY,
    SupplierName NVARCHAR(200) NOT NULL,
    ContactName  NVARCHAR(100),
    Phone        NVARCHAR(20),
    Email        NVARCHAR(200),
    Address      NVARCHAR(500),
    CreatedAt    DATETIME2     DEFAULT GETDATE()
);

-- ── 제품 테이블 ──────────────────────────────────────────────
CREATE TABLE Products (
    ProductId    INT             IDENTITY(1,1) PRIMARY KEY,
    ProductCode  NVARCHAR(50)    NOT NULL UNIQUE,
    ProductName  NVARCHAR(200)   NOT NULL,
    CategoryId   INT             FOREIGN KEY REFERENCES Categories(CategoryId),
    SupplierId   INT             FOREIGN KEY REFERENCES Suppliers(SupplierId),
    UnitPrice    DECIMAL(18, 2)  NOT NULL DEFAULT 0,
    StockQty     INT             NOT NULL DEFAULT 0,
    MinStockQty  INT             NOT NULL DEFAULT 10,
    Location     NVARCHAR(100),
    IsActive     BIT             NOT NULL DEFAULT 1,
    CreatedAt    DATETIME2       DEFAULT GETDATE(),
    UpdatedAt    DATETIME2       DEFAULT GETDATE()
);

-- ── 입출고 이력 테이블 ───────────────────────────────────────
CREATE TABLE StockHistory (
    HistoryId    INT           IDENTITY(1,1) PRIMARY KEY,
    ProductId    INT           FOREIGN KEY REFERENCES Products(ProductId),
    TxType       NVARCHAR(10)  NOT NULL CHECK (TxType IN ('IN','OUT','ADJ')),
    Quantity     INT           NOT NULL,
    UnitPrice    DECIMAL(18,2),
    Memo         NVARCHAR(500),
    CreatedBy    NVARCHAR(100) DEFAULT SYSTEM_USER,
    CreatedAt    DATETIME2     DEFAULT GETDATE()
);

-- ── 주문 테이블 ──────────────────────────────────────────────
CREATE TABLE Orders (
    OrderId      INT           IDENTITY(1,1) PRIMARY KEY,
    OrderNo      NVARCHAR(50)  NOT NULL UNIQUE,
    OrderDate    DATETIME2     DEFAULT GETDATE(),
    Status       NVARCHAR(20)  NOT NULL DEFAULT 'PENDING'
                               CHECK (Status IN ('PENDING','CONFIRMED','SHIPPED','DELIVERED','CANCELLED')),
    TotalAmount  DECIMAL(18,2) DEFAULT 0,
    CustomerName NVARCHAR(200),
    CustomerTel  NVARCHAR(20),
    ShipAddress  NVARCHAR(500),
    CreatedAt    DATETIME2     DEFAULT GETDATE()
);

-- ── 주문상세 테이블 ──────────────────────────────────────────
CREATE TABLE OrderDetails (
    DetailId     INT           IDENTITY(1,1) PRIMARY KEY,
    OrderId      INT           FOREIGN KEY REFERENCES Orders(OrderId),
    ProductId    INT           FOREIGN KEY REFERENCES Products(ProductId),
    Quantity     INT           NOT NULL,
    UnitPrice    DECIMAL(18,2) NOT NULL,
    LineTotal    AS (Quantity * UnitPrice) PERSISTED
);
GO

-- ── 인덱스 ──────────────────────────────────────────────────
CREATE INDEX IX_Products_CategoryId   ON Products(CategoryId);
CREATE INDEX IX_Products_SupplierId   ON Products(SupplierId);
CREATE INDEX IX_StockHistory_ProductId ON StockHistory(ProductId);
CREATE INDEX IX_StockHistory_CreatedAt ON StockHistory(CreatedAt);
CREATE INDEX IX_Orders_Status          ON Orders(Status);
CREATE INDEX IX_Orders_OrderDate       ON Orders(OrderDate);
GO

-- ── 뷰: 재고 현황 ────────────────────────────────────────────
CREATE VIEW vw_StockStatus AS
SELECT
    p.ProductId,
    p.ProductCode,
    p.ProductName,
    c.CategoryName,
    s.SupplierName,
    p.StockQty,
    p.MinStockQty,
    p.UnitPrice,
    p.StockQty * p.UnitPrice AS StockValue,
    CASE
        WHEN p.StockQty = 0          THEN '재고없음'
        WHEN p.StockQty < p.MinStockQty THEN '부족'
        ELSE '정상'
    END AS StockStatus,
    p.Location,
    p.UpdatedAt
FROM Products p
LEFT JOIN Categories c ON p.CategoryId = c.CategoryId
LEFT JOIN Suppliers  s ON p.SupplierId = s.SupplierId
WHERE p.IsActive = 1;
GO

-- ── 뷰: 월별 입출고 통계 ─────────────────────────────────────
CREATE VIEW vw_MonthlyStockStats AS
SELECT
    YEAR(sh.CreatedAt)  AS TxYear,
    MONTH(sh.CreatedAt) AS TxMonth,
    p.ProductName,
    sh.TxType,
    SUM(sh.Quantity)    AS TotalQty,
    SUM(sh.Quantity * sh.UnitPrice) AS TotalAmount
FROM StockHistory sh
JOIN Products p ON sh.ProductId = p.ProductId
GROUP BY YEAR(sh.CreatedAt), MONTH(sh.CreatedAt), p.ProductName, sh.TxType;
GO

-- ── 저장 프로시저: 재고 입고 처리 ────────────────────────────
CREATE PROCEDURE sp_StockIn
    @ProductId INT,
    @Quantity  INT,
    @UnitPrice DECIMAL(18,2),
    @Memo      NVARCHAR(500) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        BEGIN TRANSACTION;

        UPDATE Products
        SET StockQty  = StockQty + @Quantity,
            UpdatedAt = GETDATE()
        WHERE ProductId = @ProductId;

        INSERT INTO StockHistory (ProductId, TxType, Quantity, UnitPrice, Memo)
        VALUES (@ProductId, 'IN', @Quantity, @UnitPrice, @Memo);

        COMMIT;
        SELECT 'SUCCESS' AS Result, @Quantity AS Quantity;
    END TRY
    BEGIN CATCH
        ROLLBACK;
        SELECT 'ERROR' AS Result, ERROR_MESSAGE() AS Message;
    END CATCH
END;
GO

-- ── 저장 프로시저: 재고 출고 처리 ────────────────────────────
CREATE PROCEDURE sp_StockOut
    @ProductId INT,
    @Quantity  INT,
    @Memo      NVARCHAR(500) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        BEGIN TRANSACTION;

        DECLARE @CurrentQty INT;
        SELECT @CurrentQty = StockQty FROM Products WHERE ProductId = @ProductId;

        IF @CurrentQty < @Quantity
        BEGIN
            RAISERROR('재고 부족: 현재 재고 %d개, 요청 %d개', 16, 1, @CurrentQty, @Quantity);
        END

        UPDATE Products
        SET StockQty  = StockQty - @Quantity,
            UpdatedAt = GETDATE()
        WHERE ProductId = @ProductId;

        INSERT INTO StockHistory (ProductId, TxType, Quantity, Memo)
        VALUES (@ProductId, 'OUT', @Quantity, @Memo);

        COMMIT;
        SELECT 'SUCCESS' AS Result, @Quantity AS Quantity;
    END TRY
    BEGIN CATCH
        ROLLBACK;
        SELECT 'ERROR' AS Result, ERROR_MESSAGE() AS Message;
    END CATCH
END;
GO
