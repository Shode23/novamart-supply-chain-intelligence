/* ============================================================
   NOVAMART CONSUMER GOODS LIMITED
   SUPPLY CHAIN INTELLIGENCE PLATFORM

   PHASE 6D.2 — PRODUCT & CUSTOMER PERFORMANCE

   Module:
       02_product_customer_performance.sql

   Version:
       1.1

   Database:
       novamart_supply_chain

   Platform:
       MySQL 8.0+

   Analysis Period:
       2023–2025

   Purpose:
       Analyse product, category and customer performance,
       identify commercial concentration, and evaluate
       estimated 2025 product/category profitability.

   Primary Business Questions:
       1. Which product categories drive revenue?
       2. Which products are strongest and weakest?
       3. Which products generate the highest unit demand?
       4. Which customer segments drive revenue?
       5. Which customers are most valuable?
       6. How concentrated is customer revenue?
       7. Which products/categories generate the strongest
          estimated gross margins in 2025?

   KPI Definitions:
       Revenue
           = SUM(SalesOrderItems.LineTotal)

       Units Sold
           = SUM(SalesOrderItems.QuantitySold)

       Sales Orders
           = COUNT(DISTINCT SalesOrderID)

       2025 Estimated COGS
           = SUM(QuantitySold * StandardCost)

       2025 Estimated Gross Profit
           = Revenue - Estimated COGS

       2025 Estimated Gross Margin %
           = Estimated Gross Profit / Revenue * 100

   Profitability Methodology:
       Products.StandardCost represents the current standard-cost
       basis. Historical cost snapshots for 2023–2024 are not
       available in the operational database.

       Diagnostic analysis confirmed that applying current
       StandardCost retrospectively to 2023–2024 historical sales
       creates a temporal cost mismatch.

       Therefore:
       - Revenue, volume, product and customer analysis cover
         the full 2023–2025 period.
       - Estimated profitability is restricted to 2025.
       - 2025 profitability remains explicitly labelled as
         estimated and must not be interpreted as accounting
         gross profit.

   Analytical Grains:
       Sales-line grain
       Product grain
       Category grain
       Customer-type grain
       Customer grain

   Source Tables:
       SalesOrders
       SalesOrderItems
       Products
       Categories
       Customers

   Governance:
       - Revenue follows approved Phase 6B logic.
       - Historical 2023–2024 profitability is not inferred.
       - StandardCost is used only as a 2025 estimated COGS proxy.
       - Profitability metrics must remain explicitly labelled
         as estimated.
       - Do not join Shipments or Payments into this module.
       - Preserve analytical grain and avoid fact duplication.
       - All major revenue aggregations must reconcile to the
         approved company revenue total.

   ============================================================ */

USE novamart_supply_chain;


/* ============================================================
   SECTION 1
   PRODUCT SALES BASE
   ============================================================

   Grain:
       One row per sales order item.

   Purpose:
       Establish the reusable analytical base for product,
       category and customer analysis.

   Important:
       StandardCost is retained here for diagnostic/reference
       purposes only. Full-period historical profitability must
       not be inferred from this field.

   ============================================================ */

WITH product_sales_base AS (

    SELECT
        soi.SalesOrderItemID,
        soi.SalesOrderID,
        so.OrderDate,
        so.CustomerID,
        so.WarehouseID,
        soi.ProductID,
        p.ProductName,
        p.CategoryID,
        c.CategoryName,
        soi.QuantitySold,
        soi.UnitPrice,
        soi.DiscountAmount,
        soi.LineTotal,
        p.StandardCost

    FROM SalesOrderItems AS soi

    INNER JOIN SalesOrders AS so
        ON soi.SalesOrderID = so.SalesOrderID

    INNER JOIN Products AS p
        ON soi.ProductID = p.ProductID

    INNER JOIN Categories AS c
        ON p.CategoryID = c.CategoryID
)

SELECT *
FROM product_sales_base;


/* ============================================================
   SECTION 2
   CATEGORY PERFORMANCE — 2023–2025
   ============================================================

   Grain:
       One row per category.

   Purpose:
       Evaluate category revenue, unit demand, order activity
       and revenue contribution across the full analysis period.

   ============================================================ */

WITH category_sales AS (

    SELECT
        c.CategoryID,
        c.CategoryName,

        SUM(soi.LineTotal) AS total_revenue,

        SUM(soi.QuantitySold) AS units_sold,

        COUNT(DISTINCT soi.SalesOrderID)
            AS sales_orders

    FROM SalesOrderItems AS soi

    INNER JOIN Products AS p
        ON soi.ProductID = p.ProductID

    INNER JOIN Categories AS c
        ON p.CategoryID = c.CategoryID

    GROUP BY
        c.CategoryID,
        c.CategoryName
),

company_revenue AS (

    SELECT
        SUM(LineTotal) AS total_company_revenue
    FROM SalesOrderItems
)

SELECT
    cs.CategoryID,
    cs.CategoryName,
    cs.total_revenue,
    cs.units_sold,
    cs.sales_orders,

    ROUND(
        cs.total_revenue
        / NULLIF(cr.total_company_revenue, 0)
        * 100,
        2
    ) AS revenue_contribution_pct

FROM category_sales AS cs

CROSS JOIN company_revenue AS cr

ORDER BY
    cs.total_revenue DESC;


/* ============================================================
   SECTION 3
   ANNUAL CATEGORY PERFORMANCE
   ============================================================

   Grain:
       One row per year per category.

   ============================================================ */

SELECT
    YEAR(so.OrderDate) AS sales_year,
    c.CategoryName,

    SUM(soi.LineTotal) AS total_revenue,

    SUM(soi.QuantitySold) AS units_sold,

    COUNT(DISTINCT so.SalesOrderID)
        AS sales_orders

FROM SalesOrders AS so

INNER JOIN SalesOrderItems AS soi
    ON so.SalesOrderID = soi.SalesOrderID

INNER JOIN Products AS p
    ON soi.ProductID = p.ProductID

INNER JOIN Categories AS c
    ON p.CategoryID = c.CategoryID

GROUP BY
    YEAR(so.OrderDate),
    c.CategoryName

ORDER BY
    sales_year,
    total_revenue DESC;


/* ============================================================
   SECTION 4
   PRODUCT PERFORMANCE — 2023–2025
   ============================================================

   Grain:
       One row per product.

   Purpose:
       Rank products using full-period commercial performance
       without applying current StandardCost retrospectively.

   ============================================================ */

WITH product_performance AS (

    SELECT
        p.ProductID,
        p.ProductName,
        c.CategoryName,

        SUM(soi.LineTotal) AS total_revenue,

        SUM(soi.QuantitySold) AS units_sold,

        COUNT(DISTINCT soi.SalesOrderID)
            AS sales_orders

    FROM SalesOrderItems AS soi

    INNER JOIN Products AS p
        ON soi.ProductID = p.ProductID

    INNER JOIN Categories AS c
        ON p.CategoryID = c.CategoryID

    GROUP BY
        p.ProductID,
        p.ProductName,
        c.CategoryName
)

SELECT
    ProductID,
    ProductName,
    CategoryName,
    total_revenue,
    units_sold,
    sales_orders,

    ROUND(
        total_revenue
        / NULLIF(sales_orders, 0),
        2
    ) AS revenue_per_order

FROM product_performance

ORDER BY
    total_revenue DESC;


/* ============================================================
   SECTION 5
   TOP 10 PRODUCTS BY REVENUE
   ============================================================ */

SELECT
    p.ProductID,
    p.ProductName,
    c.CategoryName,

    SUM(soi.LineTotal) AS total_revenue,

    SUM(soi.QuantitySold) AS units_sold,

    COUNT(DISTINCT soi.SalesOrderID)
        AS sales_orders

FROM SalesOrderItems AS soi

INNER JOIN Products AS p
    ON soi.ProductID = p.ProductID

INNER JOIN Categories AS c
    ON p.CategoryID = c.CategoryID

GROUP BY
    p.ProductID,
    p.ProductName,
    c.CategoryName

ORDER BY
    total_revenue DESC

LIMIT 10;


/* ============================================================
   SECTION 6
   BOTTOM 10 PRODUCTS BY REVENUE
   ============================================================ */

SELECT
    p.ProductID,
    p.ProductName,
    c.CategoryName,

    SUM(soi.LineTotal) AS total_revenue,

    SUM(soi.QuantitySold) AS units_sold,

    COUNT(DISTINCT soi.SalesOrderID)
        AS sales_orders

FROM SalesOrderItems AS soi

INNER JOIN Products AS p
    ON soi.ProductID = p.ProductID

INNER JOIN Categories AS c
    ON p.CategoryID = c.CategoryID

GROUP BY
    p.ProductID,
    p.ProductName,
    c.CategoryName

ORDER BY
    total_revenue ASC

LIMIT 10;


/* ============================================================
   SECTION 7
   TOP PRODUCTS BY UNIT DEMAND
   ============================================================ */

SELECT
    p.ProductID,
    p.ProductName,
    c.CategoryName,

    SUM(soi.QuantitySold) AS units_sold,

    SUM(soi.LineTotal) AS total_revenue

FROM SalesOrderItems AS soi

INNER JOIN Products AS p
    ON soi.ProductID = p.ProductID

INNER JOIN Categories AS c
    ON p.CategoryID = c.CategoryID

GROUP BY
    p.ProductID,
    p.ProductName,
    c.CategoryName

ORDER BY
    units_sold DESC

LIMIT 10;


/* ============================================================
   SECTION 8
   CUSTOMER TYPE PERFORMANCE
   ============================================================ */

WITH customer_type_sales AS (

    SELECT
        cu.CustomerType,

        SUM(soi.LineTotal) AS total_revenue,

        COUNT(DISTINCT so.SalesOrderID)
            AS sales_orders,

        COUNT(DISTINCT cu.CustomerID)
            AS active_customers,

        SUM(soi.QuantitySold)
            AS units_sold

    FROM SalesOrders AS so

    INNER JOIN SalesOrderItems AS soi
        ON so.SalesOrderID = soi.SalesOrderID

    INNER JOIN Customers AS cu
        ON so.CustomerID = cu.CustomerID

    GROUP BY
        cu.CustomerType
),

company_sales AS (

    SELECT
        SUM(LineTotal) AS total_company_revenue
    FROM SalesOrderItems
)

SELECT
    cts.CustomerType,
    cts.total_revenue,
    cts.sales_orders,
    cts.active_customers,
    cts.units_sold,

    ROUND(
        cts.total_revenue
        / NULLIF(cts.sales_orders, 0),
        2
    ) AS average_order_value,

    ROUND(
        cts.total_revenue
        / NULLIF(cts.active_customers, 0),
        2
    ) AS revenue_per_customer,

    ROUND(
        cts.total_revenue
        / NULLIF(cs.total_company_revenue, 0)
        * 100,
        2
    ) AS revenue_contribution_pct

FROM customer_type_sales AS cts

CROSS JOIN company_sales AS cs

ORDER BY
    cts.total_revenue DESC;


/* ============================================================
   SECTION 9
   CUSTOMER PERFORMANCE
   ============================================================ */

WITH customer_performance AS (

    SELECT
        cu.CustomerID,
        cu.CustomerName,
        cu.CustomerType,
        cu.CustomerRegion,

        SUM(soi.LineTotal) AS total_revenue,

        COUNT(DISTINCT so.SalesOrderID)
            AS sales_orders,

        SUM(soi.QuantitySold)
            AS units_sold

    FROM Customers AS cu

    INNER JOIN SalesOrders AS so
        ON cu.CustomerID = so.CustomerID

    INNER JOIN SalesOrderItems AS soi
        ON so.SalesOrderID = soi.SalesOrderID

    GROUP BY
        cu.CustomerID,
        cu.CustomerName,
        cu.CustomerType,
        cu.CustomerRegion
)

SELECT
    CustomerID,
    CustomerName,
    CustomerType,
    CustomerRegion,
    total_revenue,
    sales_orders,
    units_sold,

    ROUND(
        total_revenue
        / NULLIF(sales_orders, 0),
        2
    ) AS average_order_value

FROM customer_performance

ORDER BY
    total_revenue DESC;


/* ============================================================
   SECTION 10
   TOP 20 CUSTOMERS
   ============================================================ */

SELECT
    cu.CustomerID,
    cu.CustomerName,
    cu.CustomerType,
    cu.CustomerRegion,

    SUM(soi.LineTotal) AS total_revenue,

    COUNT(DISTINCT so.SalesOrderID)
        AS sales_orders,

    SUM(soi.QuantitySold)
        AS units_sold,

    ROUND(
        SUM(soi.LineTotal)
        / NULLIF(
            COUNT(DISTINCT so.SalesOrderID),
            0
        ),
        2
    ) AS average_order_value

FROM Customers AS cu

INNER JOIN SalesOrders AS so
    ON cu.CustomerID = so.CustomerID

INNER JOIN SalesOrderItems AS soi
    ON so.SalesOrderID = soi.SalesOrderID

GROUP BY
    cu.CustomerID,
    cu.CustomerName,
    cu.CustomerType,
    cu.CustomerRegion

ORDER BY
    total_revenue DESC

LIMIT 20;


/* ============================================================
   SECTION 11
   CUSTOMER REVENUE CONCENTRATION
   ============================================================ */

WITH customer_revenue AS (

    SELECT
        cu.CustomerID,

        SUM(soi.LineTotal) AS total_revenue

    FROM Customers AS cu

    INNER JOIN SalesOrders AS so
        ON cu.CustomerID = so.CustomerID

    INNER JOIN SalesOrderItems AS soi
        ON so.SalesOrderID = soi.SalesOrderID

    GROUP BY
        cu.CustomerID
),

ranked_customers AS (

    SELECT
        CustomerID,
        total_revenue,

        ROW_NUMBER() OVER (
            ORDER BY total_revenue DESC
        ) AS revenue_rank

    FROM customer_revenue
),

company_revenue AS (

    SELECT
        SUM(total_revenue) AS company_revenue
    FROM customer_revenue
)

SELECT

    SUM(
        CASE
            WHEN rc.revenue_rank <= 10
            THEN rc.total_revenue
            ELSE 0
        END
    ) AS top_10_customer_revenue,

    ROUND(
        SUM(
            CASE
                WHEN rc.revenue_rank <= 10
                THEN rc.total_revenue
                ELSE 0
            END
        )
        / NULLIF(cr.company_revenue, 0)
        * 100,
        2
    ) AS top_10_revenue_concentration_pct,

    SUM(
        CASE
            WHEN rc.revenue_rank <= 20
            THEN rc.total_revenue
            ELSE 0
        END
    ) AS top_20_customer_revenue,

    ROUND(
        SUM(
            CASE
                WHEN rc.revenue_rank <= 20
                THEN rc.total_revenue
                ELSE 0
            END
        )
        / NULLIF(cr.company_revenue, 0)
        * 100,
        2
    ) AS top_20_revenue_concentration_pct

FROM ranked_customers AS rc

CROSS JOIN company_revenue AS cr

GROUP BY
    cr.company_revenue;


/* ============================================================
   SECTION 12
   CUSTOMER TYPE PERFORMANCE BY YEAR
   ============================================================ */

SELECT
    YEAR(so.OrderDate) AS sales_year,
    cu.CustomerType,

    SUM(soi.LineTotal) AS total_revenue,

    COUNT(DISTINCT so.SalesOrderID)
        AS sales_orders,

    SUM(soi.QuantitySold)
        AS units_sold,

    ROUND(
        SUM(soi.LineTotal)
        / NULLIF(
            COUNT(DISTINCT so.SalesOrderID),
            0
        ),
        2
    ) AS average_order_value

FROM SalesOrders AS so

INNER JOIN SalesOrderItems AS soi
    ON so.SalesOrderID = soi.SalesOrderID

INNER JOIN Customers AS cu
    ON so.CustomerID = cu.CustomerID

GROUP BY
    YEAR(so.OrderDate),
    cu.CustomerType

ORDER BY
    sales_year,
    total_revenue DESC;


/* ============================================================
   SECTION 13
   2025 CATEGORY ESTIMATED PROFITABILITY
   ============================================================

   Methodological Note:
       Products.StandardCost represents the current standard-cost
       basis and historical cost snapshots are unavailable.

       Estimated profitability is therefore restricted to 2025
       to reduce temporal mismatch between historical selling
       prices and the current StandardCost field.

       These metrics remain estimates and are not accounting
       gross-profit measures.

   Grain:
       One row per category.

   ============================================================ */

WITH category_profitability_2025 AS (

    SELECT
        c.CategoryID,
        c.CategoryName,

        SUM(soi.LineTotal) AS total_revenue,

        SUM(soi.QuantitySold) AS units_sold,

        SUM(
            soi.QuantitySold * p.StandardCost
        ) AS estimated_cogs

    FROM SalesOrders AS so

    INNER JOIN SalesOrderItems AS soi
        ON so.SalesOrderID = soi.SalesOrderID

    INNER JOIN Products AS p
        ON soi.ProductID = p.ProductID

    INNER JOIN Categories AS c
        ON p.CategoryID = c.CategoryID

    WHERE YEAR(so.OrderDate) = 2025

    GROUP BY
        c.CategoryID,
        c.CategoryName
)

SELECT
    CategoryID,
    CategoryName,
    total_revenue,
    units_sold,

    ROUND(
        estimated_cogs,
        2
    ) AS estimated_cogs,

    ROUND(
        total_revenue - estimated_cogs,
        2
    ) AS estimated_gross_profit,

    ROUND(
        (
            total_revenue - estimated_cogs
        )
        / NULLIF(total_revenue, 0)
        * 100,
        2
    ) AS estimated_gross_margin_pct

FROM category_profitability_2025

ORDER BY
    estimated_gross_profit DESC;


/* ============================================================
   SECTION 14
   2025 PRODUCT ESTIMATED PROFITABILITY
   ============================================================

   Methodological Note:
       Profitability is restricted to 2025 for the same temporal
       cost-alignment reason described in Section 13.

   Grain:
       One row per product.

   ============================================================ */

WITH product_profitability_2025 AS (

    SELECT
        p.ProductID,
        p.ProductName,
        c.CategoryName,

        SUM(soi.LineTotal) AS total_revenue,

        SUM(soi.QuantitySold) AS units_sold,

        SUM(
            soi.QuantitySold * p.StandardCost
        ) AS estimated_cogs

    FROM SalesOrders AS so

    INNER JOIN SalesOrderItems AS soi
        ON so.SalesOrderID = soi.SalesOrderID

    INNER JOIN Products AS p
        ON soi.ProductID = p.ProductID

    INNER JOIN Categories AS c
        ON p.CategoryID = c.CategoryID

    WHERE YEAR(so.OrderDate) = 2025

    GROUP BY
        p.ProductID,
        p.ProductName,
        c.CategoryName
)

SELECT
    ProductID,
    ProductName,
    CategoryName,
    total_revenue,
    units_sold,

    ROUND(
        estimated_cogs,
        2
    ) AS estimated_cogs,

    ROUND(
        total_revenue - estimated_cogs,
        2
    ) AS estimated_gross_profit,

    ROUND(
        (
            total_revenue - estimated_cogs
        )
        / NULLIF(total_revenue, 0)
        * 100,
        2
    ) AS estimated_gross_margin_pct

FROM product_profitability_2025

ORDER BY
    estimated_gross_profit DESC;


/* ============================================================
   SECTION 15
   CATEGORY REVENUE RECONCILIATION
   ============================================================

   Expected Result:
       reconciliation_difference = 0.00

   ============================================================ */

WITH category_revenue AS (

    SELECT
        p.CategoryID,
        SUM(soi.LineTotal) AS category_revenue

    FROM SalesOrderItems AS soi

    INNER JOIN Products AS p
        ON soi.ProductID = p.ProductID

    GROUP BY
        p.CategoryID
),

company_revenue AS (

    SELECT
        SUM(LineTotal) AS total_revenue
    FROM SalesOrderItems
)

SELECT
    SUM(cr.category_revenue)
        AS sum_of_category_revenue,

    company.total_revenue
        AS company_total_revenue,

    ROUND(
        SUM(cr.category_revenue)
        - company.total_revenue,
        2
    ) AS reconciliation_difference

FROM category_revenue AS cr

CROSS JOIN company_revenue AS company

GROUP BY
    company.total_revenue;


/* ============================================================
   SECTION 16
   CUSTOMER TYPE REVENUE RECONCILIATION
   ============================================================

   Expected Result:
       reconciliation_difference = 0.00

   ============================================================ */

WITH customer_type_revenue AS (

    SELECT
        cu.CustomerType,
        SUM(soi.LineTotal) AS customer_type_revenue

    FROM SalesOrders AS so

    INNER JOIN SalesOrderItems AS soi
        ON so.SalesOrderID = soi.SalesOrderID

    INNER JOIN Customers AS cu
        ON so.CustomerID = cu.CustomerID

    GROUP BY
        cu.CustomerType
),

company_revenue AS (

    SELECT
        SUM(LineTotal) AS total_revenue
    FROM SalesOrderItems
)

SELECT
    SUM(ctr.customer_type_revenue)
        AS sum_of_customer_type_revenue,

    company.total_revenue
        AS company_total_revenue,

    ROUND(
        SUM(ctr.customer_type_revenue)
        - company.total_revenue,
        2
    ) AS reconciliation_difference

FROM customer_type_revenue AS ctr

CROSS JOIN company_revenue AS company

GROUP BY
    company.total_revenue;


/* ============================================================
   SECTION 17
   PRODUCT REVENUE RECONCILIATION
   ============================================================

   Expected Result:
       reconciliation_difference = 0.00

   ============================================================ */

WITH product_revenue AS (

    SELECT
        ProductID,
        SUM(LineTotal) AS product_revenue

    FROM SalesOrderItems

    GROUP BY
        ProductID
),

company_revenue AS (

    SELECT
        SUM(LineTotal) AS total_revenue
    FROM SalesOrderItems
)

SELECT
    SUM(pr.product_revenue)
        AS sum_of_product_revenue,

    company.total_revenue
        AS company_total_revenue,

    ROUND(
        SUM(pr.product_revenue)
        - company.total_revenue,
        2
    ) AS reconciliation_difference

FROM product_revenue AS pr

CROSS JOIN company_revenue AS company

GROUP BY
    company.total_revenue;


/* ============================================================
   END OF PHASE 6D.2 — VERSION 1.1
   ============================================================ */
