// ============================================================
// AzMigrateDemo - Tomcat REST API (Java)
// Azure Migrate Application Discovery 데모:
//   IIS 웹앱 → Tomcat API 호출 → SQL Server
//   Dependency Map에서 3-tier 연결선 시각화됨
// ============================================================

// ── InventoryApiServlet.java ──────────────────────────────────
import javax.servlet.*;
import javax.servlet.http.*;
import javax.servlet.annotation.*;
import java.io.*;
import java.sql.*;
import java.util.Properties;

@WebServlet(name = "InventoryApiServlet", urlPatterns = {"/api/*"})
public class InventoryApiServlet extends HttpServlet {

    private static final String DB_URL  = "jdbc:sqlserver://localhost:1433;databaseName=InventoryDB;integratedSecurity=true;";
    // TODO (GitHub Copilot 제안):
    // Azure 이전 시 DB_URL을 Azure SQL Connection String으로 교체하세요.
    // 예: jdbc:sqlserver://<server>.database.windows.net:1433;database=InventoryDB;
    //     authentication=ActiveDirectoryManagedIdentity  ← Managed Identity 권장

    @Override
    protected void doGet(HttpServletRequest req, HttpServletResponse res)
            throws ServletException, IOException {

        res.setContentType("application/json;charset=UTF-8");
        res.setHeader("Access-Control-Allow-Origin", "*");

        String path = req.getPathInfo();
        PrintWriter out = res.getWriter();

        try {
            if ("/products".equals(path)) {
                out.print(getProducts());
            } else if ("/dashboard".equals(path)) {
                out.print(getDashboardStats());
            } else if (path != null && path.startsWith("/products/")) {
                int productId = Integer.parseInt(path.substring("/products/".length()));
                out.print(getProductById(productId));
            } else {
                res.setStatus(404);
                out.print("{\"error\":\"Not found\",\"path\":\"" + path + "\"}");
            }
        } catch (Exception e) {
            res.setStatus(500);
            out.print("{\"error\":\"" + e.getMessage().replace("\"","'") + "\"}");
        }
    }

    // ── 전체 제품 목록 ────────────────────────────────────────
    private String getProducts() throws Exception {
        StringBuilder sb = new StringBuilder("[");
        try (Connection conn = DriverManager.getConnection(DB_URL);
             PreparedStatement ps = conn.prepareStatement(
                "SELECT ProductId, ProductCode, ProductName, " +
                "       CategoryName, StockQty, StockStatus, " +
                "       UnitPrice, StockValue, Location " +
                "FROM vw_StockStatus ORDER BY ProductCode");
             ResultSet rs = ps.executeQuery()) {

            boolean first = true;
            while (rs.next()) {
                if (!first) sb.append(",");
                sb.append("{")
                  .append("\"productId\":").append(rs.getInt("ProductId")).append(",")
                  .append("\"productCode\":\"").append(rs.getString("ProductCode")).append("\",")
                  .append("\"productName\":\"").append(rs.getString("ProductName")).append("\",")
                  .append("\"category\":\"").append(rs.getString("CategoryName")).append("\",")
                  .append("\"stockQty\":").append(rs.getInt("StockQty")).append(",")
                  .append("\"stockStatus\":\"").append(rs.getString("StockStatus")).append("\",")
                  .append("\"unitPrice\":").append(rs.getBigDecimal("UnitPrice")).append(",")
                  .append("\"stockValue\":").append(rs.getBigDecimal("StockValue")).append(",")
                  .append("\"location\":\"").append(rs.getString("Location")).append("\"")
                  .append("}");
                first = false;
            }
        }
        return sb.append("]").toString();
    }

    // ── 대시보드 통계 API ─────────────────────────────────────
    private String getDashboardStats() throws Exception {
        try (Connection conn = DriverManager.getConnection(DB_URL);
             PreparedStatement ps = conn.prepareStatement(
                "SELECT COUNT(*) AS total, " +
                "       SUM(CASE WHEN StockQty = 0 THEN 1 ELSE 0 END) AS outOfStock, " +
                "       SUM(CASE WHEN StockQty < MinStockQty AND StockQty > 0 THEN 1 ELSE 0 END) AS lowStock, " +
                "       SUM(StockQty * UnitPrice) AS totalValue " +
                "FROM Products WHERE IsActive = 1");
             ResultSet rs = ps.executeQuery()) {

            if (rs.next()) {
                return "{" +
                    "\"totalProducts\":"  + rs.getInt("total")       + "," +
                    "\"outOfStock\":"     + rs.getInt("outOfStock")   + "," +
                    "\"lowStock\":"       + rs.getInt("lowStock")     + "," +
                    "\"totalStockValue\":" + rs.getBigDecimal("totalValue") +
                    "}";
            }
        }
        return "{}";
    }

    // ── 단일 제품 상세 API ────────────────────────────────────
    private String getProductById(int productId) throws Exception {
        try (Connection conn = DriverManager.getConnection(DB_URL);
             PreparedStatement ps = conn.prepareStatement(
                "SELECT p.ProductId, p.ProductCode, p.ProductName, " +
                "       c.CategoryName, s.SupplierName, " +
                "       p.StockQty, p.MinStockQty, p.UnitPrice, p.Location, " +
                "       p.UpdatedAt " +
                "FROM Products p " +
                "LEFT JOIN Categories c ON p.CategoryId = c.CategoryId " +
                "LEFT JOIN Suppliers  s ON p.SupplierId = s.SupplierId " +
                "WHERE p.ProductId = ?")) {

            ps.setInt(1, productId);
            try (ResultSet rs = ps.executeQuery()) {
                if (rs.next()) {
                    return "{" +
                        "\"productId\":"    + rs.getInt("ProductId")         + "," +
                        "\"productCode\":\"" + rs.getString("ProductCode")   + "\"," +
                        "\"productName\":\"" + rs.getString("ProductName")   + "\"," +
                        "\"category\":\""   + rs.getString("CategoryName")   + "\"," +
                        "\"supplier\":\""   + rs.getString("SupplierName")   + "\"," +
                        "\"stockQty\":"     + rs.getInt("StockQty")          + "," +
                        "\"minStockQty\":"  + rs.getInt("MinStockQty")       + "," +
                        "\"unitPrice\":"    + rs.getBigDecimal("UnitPrice")  + "," +
                        "\"location\":\""   + rs.getString("Location")       + "\"," +
                        "\"updatedAt\":\""  + rs.getTimestamp("UpdatedAt")   + "\"" +
                        "}";
                }
            }
        }
        return "{\"error\":\"Product not found\"}";
    }
}
