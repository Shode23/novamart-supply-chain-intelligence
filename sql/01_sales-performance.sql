/* ============================================================
   NovaMart Consumer Goods Limited
   Supply Chain Intelligence Platform
   Phase 6D.1 — Sales Performance SQL Analysis

   SQL Module: 01_sales_performance.sql
   Version: 1.0
   Database: novamart_supply_chain
   Platform: MySQL 8.0+
   Analysis Period: 2023–2025
   ============================================================ */

/* ============================================================
   NOVAMART CONSUMER GOODS LIMITED
   SUPPLY CHAIN INTELLIGENCE PLATFORM
   PHASE 6D.1 — SALES PERFORMANCE SQL ANALYSIS
   Module:
       01_sales_performance.sql
   Purpose:
       Analyse NovaMart's overall sales performance,
       revenue trends, order activity, average order value,
       units sold, and warehouse sales contribution.
   Primary Business Questions:
       1. How is revenue changing?
       2. How many sales orders are being generated?
       3. What is the average order value?
       4. How many units are being sold?
       5. How is revenue changing month-to-month?
       6. Which warehouses generate the most revenue?
       7. Is revenue growth being driven by order volume,
          order value, or both?
   KPI Definitions:
       Total Revenue
           = SUM(SalesOrderItems.LineTotal)
       Sales Orders
           = COUNT(DISTINCT SalesOrders.SalesOrderID)
       Units Sold
           = SUM(SalesOrderItems.QuantitySold)
       Average Order Value (AOV)
           = Total Revenue / Sales Orders
       Revenue Growth %
           = (Current Period Revenue - Previous Period Revenue)
             / Previous Period Revenue * 100
   Analytical Grains:
       Sales-line grain
       Order grain
       Month grain
       Warehouse grain
   Source Tables:
       SalesOrders
       SalesOrderItems
       Warehouses
   Governance:
       - Do not join multiple transaction-level fact tables
         unnecessarily.
       - Preserve the natural grain of each analysis.
       - Revenue must reconcile to the approved KPI definition.
       - Do not modify the operational database structure.
   ============================================================ */

USE novamart_supply_chain;

/* ============================================================
   SECTION 1
   SALES-LINE BASE
   ============================================================ */
WITH sales_line_base AS (
    SELECT
        soi.SalesOrderItemID,
        soi.SalesOrderID,
        so.OrderDate,
        so.WarehouseID,
        soi.ProductID,
        soi.QuantitySold,
        soi.UnitPrice,
        soi.DiscountAmount,
        soi.LineTotal
    FROM SalesOrderItems AS soi
    INNER JOIN SalesOrders AS so
        ON soi.SalesOrderID = so.SalesOrderID
)
SELECT *
FROM sales_line_base;

/* ============================================================
   SECTION 2
   OVERALL SALES PERFORMANCE
   ============================================================ */
SELECT
    SUM(soi.LineTotal) AS total_revenue,
    COUNT(DISTINCT soi.SalesOrderID) AS sales_orders,
    SUM(soi.QuantitySold) AS units_sold,
    ROUND(
        SUM(soi.LineTotal)
        / NULLIF(COUNT(DISTINCT soi.SalesOrderID), 0),
        2
    ) AS average_order_value
FROM SalesOrderItems AS soi;

/* ============================================================
   SECTION 3
   ANNUAL SALES PERFORMANCE
   ============================================================ */
WITH annual_sales AS (
    SELECT
        YEAR(so.OrderDate) AS sales_year,
        SUM(soi.LineTotal) AS total_revenue,
        COUNT(DISTINCT so.SalesOrderID) AS sales_orders,
        SUM(soi.QuantitySold) AS units_sold
    FROM SalesOrders AS so
    INNER JOIN SalesOrderItems AS soi
        ON so.SalesOrderID = soi.SalesOrderID
    GROUP BY YEAR(so.OrderDate)
)
SELECT
    sales_year,
    total_revenue,
    sales_orders,
    units_sold,
    ROUND(total_revenue / NULLIF(sales_orders, 0), 2) AS average_order_value,
    ROUND(
        (total_revenue - LAG(total_revenue) OVER (ORDER BY sales_year))
        / NULLIF(LAG(total_revenue) OVER (ORDER BY sales_year), 0) * 100,
        2
    ) AS revenue_growth_pct,
    ROUND(
        (sales_orders - LAG(sales_orders) OVER (ORDER BY sales_year))
        / NULLIF(LAG(sales_orders) OVER (ORDER BY sales_year), 0) * 100,
        2
    ) AS order_growth_pct,
    ROUND(
        (
            (total_revenue / NULLIF(sales_orders, 0))
            - LAG(total_revenue / NULLIF(sales_orders, 0)) OVER (ORDER BY sales_year)
        )
        / NULLIF(
            LAG(total_revenue / NULLIF(sales_orders, 0)) OVER (ORDER BY sales_year),
            0
        ) * 100,
        2
    ) AS aov_growth_pct
FROM annual_sales
ORDER BY sales_year;

/* ============================================================
   SECTION 4
   MONTHLY SALES PERFORMANCE
   ============================================================ */
WITH monthly_sales AS (
    SELECT
        DATE_FORMAT(so.OrderDate, '%Y-%m-01') AS sales_month,
        SUM(soi.LineTotal) AS total_revenue,
        COUNT(DISTINCT so.SalesOrderID) AS sales_orders,
        SUM(soi.QuantitySold) AS units_sold
    FROM SalesOrders AS so
    INNER JOIN SalesOrderItems AS soi
        ON so.SalesOrderID = soi.SalesOrderID
    GROUP BY DATE_FORMAT(so.OrderDate, '%Y-%m-01')
)
SELECT
    sales_month,
    total_revenue,
    sales_orders,
    units_sold,
    ROUND(total_revenue / NULLIF(sales_orders, 0), 2) AS average_order_value,
    ROUND(
        (total_revenue - LAG(total_revenue) OVER (ORDER BY sales_month))
        / NULLIF(LAG(total_revenue) OVER (ORDER BY sales_month), 0) * 100,
        2
    ) AS month_over_month_revenue_growth_pct
FROM monthly_sales
ORDER BY sales_month;

/* ============================================================
   SECTION 5
   WAREHOUSE SALES PERFORMANCE
   ============================================================ */
SELECT
    w.WarehouseID,
    w.WarehouseName,
    SUM(soi.LineTotal) AS total_revenue,
    COUNT(DISTINCT so.SalesOrderID) AS sales_orders,
    SUM(soi.QuantitySold) AS units_sold,
    ROUND(
        SUM(soi.LineTotal) / NULLIF(COUNT(DISTINCT so.SalesOrderID), 0),
        2
    ) AS average_order_value
FROM Warehouses AS w
LEFT JOIN SalesOrders AS so
    ON w.WarehouseID = so.WarehouseID
LEFT JOIN SalesOrderItems AS soi
    ON so.SalesOrderID = soi.SalesOrderID
GROUP BY w.WarehouseID, w.WarehouseName
ORDER BY total_revenue DESC;

/* ============================================================
   SECTION 6
   WAREHOUSE REVENUE CONTRIBUTION
   ============================================================ */
WITH warehouse_sales AS (
    SELECT
        w.WarehouseID,
        w.WarehouseName,
        SUM(soi.LineTotal) AS total_revenue
    FROM Warehouses AS w
    LEFT JOIN SalesOrders AS so
        ON w.WarehouseID = so.WarehouseID
    LEFT JOIN SalesOrderItems AS soi
        ON so.SalesOrderID = soi.SalesOrderID
    GROUP BY w.WarehouseID, w.WarehouseName
),
total_sales AS (
    SELECT SUM(total_revenue) AS company_revenue
    FROM warehouse_sales
)
SELECT
    ws.WarehouseID,
    ws.WarehouseName,
    ws.total_revenue,
    ROUND(
        ws.total_revenue / NULLIF(ts.company_revenue, 0) * 100,
        2
    ) AS revenue_contribution_pct
FROM warehouse_sales AS ws
CROSS JOIN total_sales AS ts
ORDER BY ws.total_revenue DESC;

/* ============================================================
   SECTION 7
   ANNUAL WAREHOUSE PERFORMANCE
   ============================================================ */
SELECT
    YEAR(so.OrderDate) AS sales_year,
    w.WarehouseName,
    SUM(soi.LineTotal) AS total_revenue,
    COUNT(DISTINCT so.SalesOrderID) AS sales_orders,
    SUM(soi.QuantitySold) AS units_sold,
    ROUND(
        SUM(soi.LineTotal) / NULLIF(COUNT(DISTINCT so.SalesOrderID), 0),
        2
    ) AS average_order_value
FROM SalesOrders AS so
INNER JOIN SalesOrderItems AS soi
    ON so.SalesOrderID = soi.SalesOrderID
INNER JOIN Warehouses AS w
    ON so.WarehouseID = w.WarehouseID
GROUP BY YEAR(so.OrderDate), w.WarehouseName
ORDER BY sales_year, total_revenue DESC;

/* ============================================================
   SECTION 8
   REVENUE RECONCILIATION
   ============================================================ */
WITH annual_revenue AS (
    SELECT
        YEAR(so.OrderDate) AS sales_year,
        SUM(soi.LineTotal) AS annual_revenue
    FROM SalesOrders AS so
    INNER JOIN SalesOrderItems AS soi
        ON so.SalesOrderID = soi.SalesOrderID
    GROUP BY YEAR(so.OrderDate)
),
company_revenue AS (
    SELECT SUM(LineTotal) AS total_revenue
    FROM SalesOrderItems
)
SELECT
    SUM(ar.annual_revenue) AS sum_of_annual_revenue,
    cr.total_revenue AS company_total_revenue,
    ROUND(SUM(ar.annual_revenue) - cr.total_revenue, 2) AS reconciliation_difference
FROM annual_revenue AS ar
CROSS JOIN company_revenue AS cr
GROUP BY cr.total_revenue;

/* ============================================================
   SECTION 9
   WAREHOUSE REVENUE RECONCILIATION
   ============================================================ */
WITH warehouse_revenue AS (
    SELECT
        so.WarehouseID,
        SUM(soi.LineTotal) AS warehouse_revenue
    FROM SalesOrders AS so
    INNER JOIN SalesOrderItems AS soi
        ON so.SalesOrderID = soi.SalesOrderID
    GROUP BY so.WarehouseID
),
company_revenue AS (
    SELECT SUM(LineTotal) AS total_revenue
    FROM SalesOrderItems
)
SELECT
    SUM(wr.warehouse_revenue) AS sum_of_warehouse_revenue,
    cr.total_revenue AS company_total_revenue,
    ROUND(SUM(wr.warehouse_revenue) - cr.total_revenue, 2) AS reconciliation_difference
FROM warehouse_revenue AS wr
CROSS JOIN company_revenue AS cr
GROUP BY cr.total_revenue;

/* ============================================================
   SECTION 10
   SALES PERFORMANCE DIAGNOSTIC
   ============================================================ */
WITH annual_sales AS (
    SELECT
        YEAR(so.OrderDate) AS sales_year,
        SUM(soi.LineTotal) AS total_revenue,
        COUNT(DISTINCT so.SalesOrderID) AS sales_orders
    FROM SalesOrders AS so
    INNER JOIN SalesOrderItems AS soi
        ON so.SalesOrderID = soi.SalesOrderID
    GROUP BY YEAR(so.OrderDate)
)
SELECT
    sales_year,
    total_revenue,
    sales_orders,
    ROUND(total_revenue / NULLIF(sales_orders, 0), 2) AS average_order_value
FROM annual_sales
ORDER BY sales_year;

/* ============================================================
   END OF PHASE 6D.1

   Expected Analytical Outputs:
   1. Overall Sales Performance
   2. Annual Sales Performance
   3. Monthly Sales Performance
   4. Warehouse Sales Performance
   5. Warehouse Revenue Contribution
   6. Annual Warehouse Performance
   7. Revenue Reconciliation
   8. Warehouse Revenue Reconciliation
   9. Revenue Driver Diagnostic

   Analytical Principle:
   The module intentionally separates Revenue from Orders from AOV
   so that revenue growth can later be decomposed into changes in
   order volume and order value.

   This prevents the analysis from stopping at:
   "Revenue increased."

   Instead, it allows us to determine what actually drove the increase.
   ============================================================ */
