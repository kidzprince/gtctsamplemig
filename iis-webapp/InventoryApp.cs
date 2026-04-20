// ============================================================
// AzMigrateDemo - 재고관리 시스템
// ASP.NET MVC 4.8 기반 (.NET Framework)
// GitHub Copilot으로 Azure App Service 이전 데모용
// ============================================================

// ── Models/Product.cs ────────────────────────────────────────
using System;
using System.ComponentModel.DataAnnotations;

namespace InventoryApp.Models
{
    public class Product
    {
        public int    ProductId   { get; set; }

        [Required]
        [StringLength(50)]
        [Display(Name = "제품코드")]
        public string ProductCode { get; set; }

        [Required]
        [StringLength(200)]
        [Display(Name = "제품명")]
        public string ProductName { get; set; }

        [Display(Name = "카테고리")]
        public int?   CategoryId  { get; set; }

        [Display(Name = "공급업체")]
        public int?   SupplierId  { get; set; }

        [Required]
        [Range(0, double.MaxValue)]
        [Display(Name = "단가")]
        public decimal UnitPrice  { get; set; }

        [Display(Name = "재고수량")]
        public int    StockQty    { get; set; }

        [Display(Name = "최소재고")]
        public int    MinStockQty { get; set; }

        [Display(Name = "위치")]
        public string Location    { get; set; }

        public bool   IsActive    { get; set; } = true;
        public DateTime CreatedAt { get; set; }
        public DateTime UpdatedAt { get; set; }

        // 조인 필드
        public string CategoryName { get; set; }
        public string SupplierName { get; set; }
        public string StockStatus  { get; set; }
        public decimal StockValue  { get; set; }
    }

    public class StockHistory
    {
        public int     HistoryId  { get; set; }
        public int     ProductId  { get; set; }
        public string  TxType     { get; set; }
        public int     Quantity   { get; set; }
        public decimal UnitPrice  { get; set; }
        public string  Memo       { get; set; }
        public string  CreatedBy  { get; set; }
        public DateTime CreatedAt { get; set; }
        public string  ProductName { get; set; }
    }

    public class Order
    {
        public int      OrderId      { get; set; }
        public string   OrderNo      { get; set; }
        public DateTime OrderDate    { get; set; }
        public string   Status       { get; set; }
        public decimal  TotalAmount  { get; set; }
        public string   CustomerName { get; set; }
        public string   CustomerTel  { get; set; }
        public string   ShipAddress  { get; set; }
        public int      ItemCount    { get; set; }
    }

    public class DashboardViewModel
    {
        public int     TotalProducts    { get; set; }
        public int     LowStockCount    { get; set; }
        public int     OutOfStockCount  { get; set; }
        public decimal TotalStockValue  { get; set; }
        public int     PendingOrders    { get; set; }
        public System.Collections.Generic.List<Product>      RecentLowStock { get; set; }
        public System.Collections.Generic.List<StockHistory> RecentHistory  { get; set; }
    }
}


// ── Data/InventoryRepository.cs ──────────────────────────────
using System.Collections.Generic;
using System.Configuration;
using System.Data;
using System.Data.SqlClient;
using InventoryApp.Models;

namespace InventoryApp.Data
{
    // TODO (GitHub Copilot 제안): 
    // Azure 이전 시 이 클래스를 Entity Framework Core + Azure SQL로 대체하거나
    // Repository 패턴에 DI(Dependency Injection)를 적용하세요.
    public class InventoryRepository
    {
        private readonly string _connStr;

        public InventoryRepository()
        {
            _connStr = ConfigurationManager.ConnectionStrings["InventoryDB"].ConnectionString;
        }

        // ── 대시보드 통계 ─────────────────────────────────────
        public DashboardViewModel GetDashboard()
        {
            var model = new DashboardViewModel
            {
                RecentLowStock = new List<Product>(),
                RecentHistory  = new List<StockHistory>()
            };

            using (var conn = new SqlConnection(_connStr))
            {
                conn.Open();

                // 통계 쿼리
                var sql = @"
                    SELECT
                        COUNT(*)                                        AS TotalProducts,
                        SUM(CASE WHEN StockQty < MinStockQty AND StockQty > 0 THEN 1 ELSE 0 END) AS LowStock,
                        SUM(CASE WHEN StockQty = 0 THEN 1 ELSE 0 END)  AS OutOfStock,
                        SUM(StockQty * UnitPrice)                       AS TotalValue
                    FROM Products WHERE IsActive = 1;

                    SELECT TOP 5 ProductCode, ProductName, CategoryName,
                                 StockQty, MinStockQty, StockStatus, Location
                    FROM vw_StockStatus
                    WHERE StockStatus IN (N'부족', N'재고없음')
                    ORDER BY StockQty ASC;

                    SELECT TOP 10 sh.TxType, sh.Quantity, sh.Memo, sh.CreatedAt,
                                  p.ProductName
                    FROM StockHistory sh
                    JOIN Products p ON sh.ProductId = p.ProductId
                    ORDER BY sh.CreatedAt DESC;

                    SELECT COUNT(*) FROM Orders WHERE Status = 'PENDING';";

                using (var cmd = new SqlCommand(sql, conn))
                using (var reader = cmd.ExecuteReader())
                {
                    if (reader.Read())
                    {
                        model.TotalProducts   = reader.GetInt32(0);
                        model.LowStockCount   = reader.GetInt32(1);
                        model.OutOfStockCount = reader.GetInt32(2);
                        model.TotalStockValue = reader.IsDBNull(3) ? 0 : reader.GetDecimal(3);
                    }
                    reader.NextResult();
                    while (reader.Read())
                        model.RecentLowStock.Add(new Product {
                            ProductCode  = reader["ProductCode"].ToString(),
                            ProductName  = reader["ProductName"].ToString(),
                            CategoryName = reader["CategoryName"].ToString(),
                            StockQty     = (int)reader["StockQty"],
                            MinStockQty  = (int)reader["MinStockQty"],
                            StockStatus  = reader["StockStatus"].ToString(),
                            Location     = reader["Location"].ToString()
                        });
                    reader.NextResult();
                    while (reader.Read())
                        model.RecentHistory.Add(new StockHistory {
                            TxType      = reader["TxType"].ToString(),
                            Quantity    = (int)reader["Quantity"],
                            Memo        = reader["Memo"].ToString(),
                            CreatedAt   = (System.DateTime)reader["CreatedAt"],
                            ProductName = reader["ProductName"].ToString()
                        });
                    reader.NextResult();
                    if (reader.Read())
                        model.PendingOrders = reader.GetInt32(0);
                }
            }
            return model;
        }

        // ── 제품 목록 조회 ────────────────────────────────────
        public List<Product> GetProducts(string keyword = null, int? categoryId = null)
        {
            var list = new List<Product>();
            var sql  = @"SELECT ProductId, ProductCode, ProductName,
                                CategoryName, SupplierName,
                                StockQty, MinStockQty, UnitPrice,
                                StockValue, StockStatus, Location, UpdatedAt
                         FROM vw_StockStatus
                         WHERE 1=1
                         AND (@keyword    IS NULL OR ProductName LIKE '%'+@keyword+'%'
                                            OR ProductCode LIKE '%'+@keyword+'%')
                         AND (@categoryId IS NULL OR CategoryId = @categoryId)
                         ORDER BY CategoryName, ProductCode";

            using (var conn = new SqlConnection(_connStr))
            using (var cmd  = new SqlCommand(sql, conn))
            {
                cmd.Parameters.AddWithValue("@keyword",    (object)keyword    ?? DBNull.Value);
                cmd.Parameters.AddWithValue("@categoryId", (object)categoryId ?? DBNull.Value);
                conn.Open();
                using (var reader = cmd.ExecuteReader())
                    while (reader.Read())
                        list.Add(new Product {
                            ProductId    = (int)reader["ProductId"],
                            ProductCode  = reader["ProductCode"].ToString(),
                            ProductName  = reader["ProductName"].ToString(),
                            CategoryName = reader["CategoryName"].ToString(),
                            SupplierName = reader["SupplierName"].ToString(),
                            StockQty     = (int)reader["StockQty"],
                            MinStockQty  = (int)reader["MinStockQty"],
                            UnitPrice    = (decimal)reader["UnitPrice"],
                            StockValue   = (decimal)reader["StockValue"],
                            StockStatus  = reader["StockStatus"].ToString(),
                            Location     = reader["Location"].ToString()
                        });
            }
            return list;
        }

        // ── 입출고 처리 ───────────────────────────────────────
        public string ProcessStock(int productId, string txType, int qty,
                                   decimal unitPrice = 0, string memo = null)
        {
            var procName = txType == "IN" ? "sp_StockIn" : "sp_StockOut";
            using (var conn = new SqlConnection(_connStr))
            using (var cmd  = new SqlCommand(procName, conn))
            {
                cmd.CommandType = CommandType.StoredProcedure;
                cmd.Parameters.AddWithValue("@ProductId", productId);
                cmd.Parameters.AddWithValue("@Quantity",  qty);
                if (txType == "IN")
                    cmd.Parameters.AddWithValue("@UnitPrice", unitPrice);
                cmd.Parameters.AddWithValue("@Memo", (object)memo ?? DBNull.Value);
                conn.Open();
                using (var reader = cmd.ExecuteReader())
                    if (reader.Read())
                        return reader["Result"].ToString();
            }
            return "ERROR";
        }
    }
}


// ── Controllers/HomeController.cs ────────────────────────────
using System.Web.Mvc;
using InventoryApp.Data;

namespace InventoryApp.Controllers
{
    public class HomeController : Controller
    {
        private readonly InventoryRepository _repo = new InventoryRepository();

        // GET: /
        public ActionResult Index()
        {
            var model = _repo.GetDashboard();
            return View(model);
        }
    }
}


// ── Controllers/ProductController.cs ─────────────────────────
using System.Web.Mvc;
using InventoryApp.Data;

namespace InventoryApp.Controllers
{
    public class ProductController : Controller
    {
        private readonly InventoryRepository _repo = new InventoryRepository();

        // GET: /Product
        public ActionResult Index(string keyword, int? categoryId)
        {
            ViewBag.Keyword    = keyword;
            ViewBag.CategoryId = categoryId;
            var model = _repo.GetProducts(keyword, categoryId);
            return View(model);
        }

        // POST: /Product/StockIn
        [HttpPost]
        public ActionResult StockIn(int productId, int quantity,
                                    decimal unitPrice, string memo)
        {
            var result = _repo.ProcessStock(productId, "IN", quantity, unitPrice, memo);
            TempData["Message"] = result == "SUCCESS"
                ? $"입고 처리 완료 ({quantity}개)"
                : "입고 처리 실패";
            return RedirectToAction("Index");
        }

        // POST: /Product/StockOut
        [HttpPost]
        public ActionResult StockOut(int productId, int quantity, string memo)
        {
            var result = _repo.ProcessStock(productId, "OUT", quantity, memo: memo);
            TempData["Message"] = result == "SUCCESS"
                ? $"출고 처리 완료 ({quantity}개)"
                : "출고 처리 실패 (재고 부족 확인)";
            return RedirectToAction("Index");
        }
    }
}
