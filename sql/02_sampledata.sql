-- ============================================================
-- AzMigrateDemo - 샘플 데이터 입력
-- ============================================================

USE InventoryDB;
GO

-- ── 카테고리 ─────────────────────────────────────────────────
INSERT INTO Categories (CategoryName, Description) VALUES
(N'전자제품',   N'컴퓨터, 모니터, 주변기기 등 전자 제품'),
(N'사무용품',   N'문구류, 복사지, 파일 등 사무 용품'),
(N'네트워크',   N'스위치, 라우터, 케이블 등 네트워크 장비'),
(N'소모품',     N'토너, 잉크, 배터리 등 소모성 자재'),
(N'가구/인테리어', N'책상, 의자, 캐비닛 등 사무 가구');
GO

-- ── 공급업체 ─────────────────────────────────────────────────
INSERT INTO Suppliers (SupplierName, ContactName, Phone, Email, Address) VALUES
(N'삼성전자 B2B',    N'김영업',   N'02-1234-5678', N'b2b@samsung.com',  N'서울시 서초구 서초대로 1'),
(N'LG전자 기업영업', N'이담당',   N'02-2345-6789', N'corp@lge.com',      N'서울시 영등포구 여의대로 128'),
(N'한국HP',          N'박매니저', N'02-3456-7890', N'sales@hp.co.kr',    N'서울시 강남구 테헤란로 521'),
(N'시스코코리아',    N'최엔지니어', N'02-4567-8901', N'sales@cisco.co.kr', N'서울시 강남구 역삼로 180'),
(N'교보문고 기업몰', N'정과장',   N'02-5678-9012', N'corp@kyobo.com',    N'서울시 종로구 종로 1');
GO

-- ── 제품 ─────────────────────────────────────────────────────
INSERT INTO Products (ProductCode, ProductName, CategoryId, SupplierId, UnitPrice, StockQty, MinStockQty, Location) VALUES
-- 전자제품
(N'EL-001', N'삼성 모니터 27인치 4K',       1, 1, 450000,  25, 5,  N'A-01-01'),
(N'EL-002', N'LG 노트북 그램 16',            1, 2, 1890000, 10, 3,  N'A-01-02'),
(N'EL-003', N'HP 레이저젯 복합기',           1, 3, 520000,  8,  2,  N'A-01-03'),
(N'EL-004', N'삼성 SSD 1TB',                 1, 1, 89000,   50, 10, N'A-02-01'),
(N'EL-005', N'무선 키보드+마우스 세트',      1, 2, 75000,   30, 10, N'A-02-02'),
-- 사무용품
(N'OF-001', N'A4 복사지 (박스)',             2, 5, 35000,   40, 20, N'B-01-01'),
(N'OF-002', N'볼펜 세트 (12개입)',           2, 5, 12000,   100, 30, N'B-01-02'),
(N'OF-003', N'3공 바인더 (10개)',            2, 5, 28000,   60, 20, N'B-01-03'),
(N'OF-004', N'포스트잇 대용량 세트',         2, 5, 18000,   80, 30, N'B-02-01'),
(N'OF-005', N'스테이플러 + 침 세트',         2, 5, 22000,   45, 15, N'B-02-02'),
-- 네트워크
(N'NW-001', N'시스코 스위치 24포트',         3, 4, 680000,  5,  2,  N'C-01-01'),
(N'NW-002', N'시스코 라우터 ISR 4321',       3, 4, 2800000, 3,  1,  N'C-01-02'),
(N'NW-003', N'CAT6 UTP 케이블 50m',          3, 4, 25000,   100, 20, N'C-02-01'),
(N'NW-004', N'광케이블 LC-LC 10m',           3, 4, 45000,   30, 10, N'C-02-02'),
(N'NW-005', N'AP 무선액세스포인트',          3, 4, 380000,  12, 3,  N'C-01-03'),
-- 소모품
(N'CS-001', N'HP 레이저 토너 검정',          4, 3, 89000,   20, 5,  N'D-01-01'),
(N'CS-002', N'HP 레이저 토너 컬러 세트',     4, 3, 245000,  8,  3,  N'D-01-02'),
(N'CS-003', N'AA 건전지 (20개입)',           4, 5, 15000,   60, 20, N'D-02-01'),
(N'CS-004', N'USB-C 케이블 1m',              4, 1, 12000,   80, 20, N'D-02-02'),
(N'CS-005', N'멀티탭 6구 3m',               4, 2, 28000,   35, 10, N'D-02-03');
GO

-- ── 입출고 이력 (3개월치) ────────────────────────────────────
-- 1월 입고
EXEC sp_StockIn @ProductId=1,  @Quantity=30, @UnitPrice=430000, @Memo=N'1월 정기 발주';
EXEC sp_StockIn @ProductId=2,  @Quantity=12, @UnitPrice=1800000,@Memo=N'1월 정기 발주';
EXEC sp_StockIn @ProductId=6,  @Quantity=50, @UnitPrice=33000,  @Memo=N'1월 사무용품 발주';
EXEC sp_StockIn @ProductId=11, @Quantity=6,  @UnitPrice=650000, @Memo=N'1월 네트워크 발주';
EXEC sp_StockIn @ProductId=16, @Quantity=25, @UnitPrice=85000,  @Memo=N'1월 소모품 발주';

-- 1월 출고
EXEC sp_StockOut @ProductId=1,  @Quantity=5,  @Memo=N'IT팀 지급';
EXEC sp_StockOut @ProductId=2,  @Quantity=2,  @Memo=N'영업팀 지급';
EXEC sp_StockOut @ProductId=6,  @Quantity=10, @Memo=N'총무팀 지급';
EXEC sp_StockOut @ProductId=16, @Quantity=5,  @Memo=N'프린터 토너 교체';

-- 2월 입고
EXEC sp_StockIn @ProductId=3,  @Quantity=10, @UnitPrice=500000, @Memo=N'2월 정기 발주';
EXEC sp_StockIn @ProductId=4,  @Quantity=60, @UnitPrice=85000,  @Memo=N'2월 정기 발주';
EXEC sp_StockIn @ProductId=7,  @Quantity=120,@UnitPrice=11000,  @Memo=N'2월 사무용품 발주';
EXEC sp_StockIn @ProductId=13, @Quantity=120,@UnitPrice=23000,  @Memo=N'2월 네트워크 발주';

-- 2월 출고
EXEC sp_StockOut @ProductId=3,  @Quantity=2,  @Memo=N'총무팀 지급';
EXEC sp_StockOut @ProductId=4,  @Quantity=10, @Memo=N'개발팀 SSD 업그레이드';
EXEC sp_StockOut @ProductId=7,  @Quantity=30, @Memo=N'각 부서 지급';
EXEC sp_StockOut @ProductId=13, @Quantity=20, @Memo=N'회의실 네트워크 공사';

-- 3월 입고
EXEC sp_StockIn @ProductId=5,  @Quantity=40, @UnitPrice=72000,  @Memo=N'3월 정기 발주';
EXEC sp_StockIn @ProductId=15, @Quantity=15, @UnitPrice=360000, @Memo=N'3월 AP 추가 도입';
EXEC sp_StockIn @ProductId=17, @Quantity=10, @UnitPrice=240000, @Memo=N'3월 소모품 발주';
EXEC sp_StockIn @ProductId=20, @Quantity=40, @UnitPrice=26000,  @Memo=N'3월 소모품 발주';

-- 3월 출고
EXEC sp_StockOut @ProductId=5,  @Quantity=10, @Memo=N'전 직원 마우스 교체';
EXEC sp_StockOut @ProductId=15, @Quantity=3,  @Memo=N'신규 층 AP 설치';
EXEC sp_StockOut @ProductId=17, @Quantity=2,  @Memo=N'컬러 프린터 토너 교체';
EXEC sp_StockOut @ProductId=20, @Quantity=8,  @Memo=N'각 팀 멀티탭 지급';
GO

-- ── 주문 데이터 ──────────────────────────────────────────────
INSERT INTO Orders (OrderNo, OrderDate, Status, TotalAmount, CustomerName, CustomerTel, ShipAddress) VALUES
(N'ORD-2026-001', '2026-01-05', 'DELIVERED', 4750000, N'ABC 컨설팅', N'02-111-2222', N'서울시 강남구 역삼동 100'),
(N'ORD-2026-002', '2026-01-15', 'DELIVERED', 1260000, N'XYZ 물산',   N'02-222-3333', N'서울시 마포구 합정동 200'),
(N'ORD-2026-003', '2026-02-03', 'SHIPPED',   890000,  N'한국 IT',    N'02-333-4444', N'서울시 송파구 문정동 300'),
(N'ORD-2026-004', '2026-02-20', 'CONFIRMED', 2340000, N'미래 솔루션', N'02-444-5555', N'경기도 성남시 분당구 판교로 1'),
(N'ORD-2026-005', '2026-03-01', 'PENDING',   560000,  N'글로벌 트레이드', N'02-555-6666', N'서울시 중구 을지로 100');
GO

INSERT INTO OrderDetails (OrderId, ProductId, Quantity, UnitPrice) VALUES
(1, 1, 5, 450000),  -- 모니터 5대
(1, 2, 2, 1890000), -- 노트북 2대 (3대분에서 일부)
(2, 11, 1, 680000), -- 시스코 스위치
(2, 13, 24, 25000), -- CAT6 케이블
(3, 3, 1, 520000),  -- 복합기
(3, 16, 4, 89000),  -- 토너
(4, 12, 1, 2800000),-- 라우터 (금액 조정)
(4, 15, 1, 380000), -- AP
(5, 6, 10, 35000),  -- 복사지
(5, 7, 10, 12000);  -- 볼펜
GO

-- ── 확인 쿼리 ────────────────────────────────────────────────
SELECT N'=== 재고 현황 ===' AS Info;
SELECT ProductCode, ProductName, CategoryName, StockQty, StockStatus, StockValue
FROM vw_StockStatus
ORDER BY CategoryName, ProductCode;

SELECT N'=== 월별 통계 ===' AS Info;
SELECT TxYear, TxMonth, TxType, SUM(TotalQty) AS Qty, SUM(TotalAmount) AS Amount
FROM vw_MonthlyStockStats
GROUP BY TxYear, TxMonth, TxType
ORDER BY TxYear, TxMonth, TxType;

SELECT N'=== 주문 현황 ===' AS Info;
SELECT o.OrderNo, o.Status, o.CustomerName, o.TotalAmount,
       COUNT(od.DetailId) AS ItemCount
FROM Orders o
LEFT JOIN OrderDetails od ON o.OrderId = od.OrderId
GROUP BY o.OrderNo, o.Status, o.CustomerName, o.TotalAmount
ORDER BY o.OrderNo;
GO
