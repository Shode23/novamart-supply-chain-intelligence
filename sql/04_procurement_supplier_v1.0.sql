/* ============================================================
   NOVAMART CONSUMER GOODS LIMITED
   SUPPLY CHAIN INTELLIGENCE PLATFORM

   PHASE 6D.4 — PROCUREMENT & SUPPLIER PERFORMANCE

   Module:
       04_procurement_supplier.sql

   Version:
       1.0

   Database:
       novamart_supply_chain

   Platform:
       MySQL 8.0+

   Analysis Period:
       2023–2025

   Purpose:
       Evaluate procurement spend, supplier concentration,
       procurement cost trends, delivery lead times, supplier
       reliability and category-level supplier dependency.

   Core Definitions:
       Procurement Spend = SUM(PurchaseOrderItems.LineTotal)
       Units Procured = SUM(PurchaseOrderItems.QuantityOrdered)
       Purchase Orders = COUNT(DISTINCT PurchaseOrderID)
       Average PO Value = Procurement Spend / Purchase Orders
       Average Procurement Unit Cost = Procurement Spend / Units Procured
       Actual Lead Time = DATEDIFF(ActualDeliveryDate, PurchaseOrderDate)
       Supplier On-Time Delivery = ActualDeliveryDate <= ExpectedDeliveryDate

   Governance:
       - Historical UnitCost is transaction-level and valid for
         2023–2025 trend analysis.
       - Do not use Products.StandardCost for procurement spend.
       - Delivery reliability is measured at purchase-order grain.
       - Avoid fact duplication by aggregating at the required grain.

   ============================================================ */

USE novamart_supply_chain;


/* SECTION 1 — PROCUREMENT ANALYTICAL BASE */
WITH procurement_base AS (
    SELECT
        poi.PurchaseOrderItemID,
        poi.PurchaseOrderID,
        po.SupplierID,
        s.SupplierName,
        po.EmployeeID,
        po.PurchaseOrderDate,
        po.ExpectedDeliveryDate,
        po.ActualDeliveryDate,
        po.PurchaseOrderStatus,
        poi.ProductID,
        p.ProductName,
        p.CategoryID,
        c.CategoryName,
        poi.QuantityOrdered,
        poi.UnitCost,
        poi.LineTotal,
        DATEDIFF(po.ExpectedDeliveryDate, po.PurchaseOrderDate) AS expected_lead_time_days,
        DATEDIFF(po.ActualDeliveryDate, po.PurchaseOrderDate) AS actual_lead_time_days,
        CASE
            WHEN po.ActualDeliveryDate <= po.ExpectedDeliveryDate THEN 1
            ELSE 0
        END AS delivered_on_time_flag
    FROM PurchaseOrderItems poi
    JOIN PurchaseOrders po ON poi.PurchaseOrderID = po.PurchaseOrderID
    JOIN Suppliers s ON po.SupplierID = s.SupplierID
    JOIN Products p ON poi.ProductID = p.ProductID
    JOIN Categories c ON p.CategoryID = c.CategoryID
)
SELECT * FROM procurement_base;


/* SECTION 2 — COMPANY PROCUREMENT SUMMARY */
SELECT
    ROUND(SUM(poi.LineTotal),2) AS total_procurement_spend,
    COUNT(DISTINCT po.PurchaseOrderID) AS purchase_orders,
    SUM(poi.QuantityOrdered) AS units_procured,
    ROUND(
        SUM(poi.LineTotal) /
        NULLIF(COUNT(DISTINCT po.PurchaseOrderID),0),2
    ) AS average_purchase_order_value,
    ROUND(
        SUM(poi.LineTotal) /
        NULLIF(SUM(poi.QuantityOrdered),0),2
    ) AS average_procurement_unit_cost
FROM PurchaseOrders po
JOIN PurchaseOrderItems poi
    ON po.PurchaseOrderID = poi.PurchaseOrderID;


/* SECTION 3 — ANNUAL PROCUREMENT PERFORMANCE */
SELECT
    YEAR(po.PurchaseOrderDate) AS procurement_year,
    ROUND(SUM(poi.LineTotal),2) AS procurement_spend,
    COUNT(DISTINCT po.PurchaseOrderID) AS purchase_orders,
    SUM(poi.QuantityOrdered) AS units_procured,
    ROUND(
        SUM(poi.LineTotal) /
        NULLIF(COUNT(DISTINCT po.PurchaseOrderID),0),2
    ) AS average_purchase_order_value,
    ROUND(
        SUM(poi.LineTotal) /
        NULLIF(SUM(poi.QuantityOrdered),0),2
    ) AS average_procurement_unit_cost
FROM PurchaseOrders po
JOIN PurchaseOrderItems poi
    ON po.PurchaseOrderID = poi.PurchaseOrderID
GROUP BY YEAR(po.PurchaseOrderDate)
ORDER BY procurement_year;


/* SECTION 4 — ANNUAL PROCUREMENT GROWTH */
WITH annual_procurement AS (
    SELECT
        YEAR(po.PurchaseOrderDate) AS procurement_year,
        SUM(poi.LineTotal) AS procurement_spend,
        COUNT(DISTINCT po.PurchaseOrderID) AS purchase_orders,
        SUM(poi.QuantityOrdered) AS units_procured
    FROM PurchaseOrders po
    JOIN PurchaseOrderItems poi
        ON po.PurchaseOrderID = poi.PurchaseOrderID
    GROUP BY YEAR(po.PurchaseOrderDate)
),
growth_base AS (
    SELECT
        *,
        LAG(procurement_spend) OVER (ORDER BY procurement_year) AS prior_year_spend,
        LAG(purchase_orders) OVER (ORDER BY procurement_year) AS prior_year_orders,
        LAG(units_procured) OVER (ORDER BY procurement_year) AS prior_year_units
    FROM annual_procurement
)
SELECT
    procurement_year,
    ROUND(procurement_spend,2) AS procurement_spend,
    purchase_orders,
    units_procured,
    ROUND((procurement_spend-prior_year_spend)/NULLIF(prior_year_spend,0)*100,2)
        AS procurement_spend_growth_pct,
    ROUND((purchase_orders-prior_year_orders)/NULLIF(prior_year_orders,0)*100,2)
        AS purchase_order_growth_pct,
    ROUND((units_procured-prior_year_units)/NULLIF(prior_year_units,0)*100,2)
        AS units_procured_growth_pct
FROM growth_base
ORDER BY procurement_year;


/* SECTION 5 — SUPPLIER PROCUREMENT PERFORMANCE */
WITH supplier_spend AS (
    SELECT
        s.SupplierID,
        s.SupplierName,
        SUM(poi.LineTotal) AS procurement_spend,
        COUNT(DISTINCT po.PurchaseOrderID) AS purchase_orders,
        SUM(poi.QuantityOrdered) AS units_procured,
        COUNT(DISTINCT poi.ProductID) AS products_supplied
    FROM Suppliers s
    JOIN PurchaseOrders po ON s.SupplierID = po.SupplierID
    JOIN PurchaseOrderItems poi ON po.PurchaseOrderID = poi.PurchaseOrderID
    GROUP BY s.SupplierID, s.SupplierName
),
company_spend AS (
    SELECT SUM(procurement_spend) AS total_procurement_spend
    FROM supplier_spend
)
SELECT
    ss.SupplierID,
    ss.SupplierName,
    ROUND(ss.procurement_spend,2) AS procurement_spend,
    ss.purchase_orders,
    ss.units_procured,
    ss.products_supplied,
    ROUND(ss.procurement_spend/NULLIF(ss.purchase_orders,0),2)
        AS average_purchase_order_value,
    ROUND(ss.procurement_spend/NULLIF(cs.total_procurement_spend,0)*100,2)
        AS procurement_spend_share_pct
FROM supplier_spend ss
CROSS JOIN company_spend cs
ORDER BY ss.procurement_spend DESC;


/* SECTION 6 — TOP 10 SUPPLIERS BY PROCUREMENT SPEND */
SELECT
    s.SupplierID,
    s.SupplierName,
    ROUND(SUM(poi.LineTotal),2) AS procurement_spend,
    COUNT(DISTINCT po.PurchaseOrderID) AS purchase_orders,
    SUM(poi.QuantityOrdered) AS units_procured
FROM Suppliers s
JOIN PurchaseOrders po ON s.SupplierID = po.SupplierID
JOIN PurchaseOrderItems poi ON po.PurchaseOrderID = poi.PurchaseOrderID
GROUP BY s.SupplierID, s.SupplierName
ORDER BY procurement_spend DESC
LIMIT 10;


/* SECTION 7 — SUPPLIER SPEND CONCENTRATION */
WITH supplier_spend AS (
    SELECT
        s.SupplierID,
        SUM(poi.LineTotal) AS procurement_spend
    FROM Suppliers s
    JOIN PurchaseOrders po ON s.SupplierID = po.SupplierID
    JOIN PurchaseOrderItems poi ON po.PurchaseOrderID = poi.PurchaseOrderID
    GROUP BY s.SupplierID
),
ranked_suppliers AS (
    SELECT
        SupplierID,
        procurement_spend,
        ROW_NUMBER() OVER (ORDER BY procurement_spend DESC) AS spend_rank
    FROM supplier_spend
),
company_spend AS (
    SELECT SUM(procurement_spend) AS total_procurement_spend
    FROM supplier_spend
)
SELECT
    ROUND(SUM(CASE WHEN spend_rank<=3 THEN procurement_spend ELSE 0 END),2)
        AS top_3_supplier_spend,
    ROUND(
        SUM(CASE WHEN spend_rank<=3 THEN procurement_spend ELSE 0 END) /
        NULLIF(total_procurement_spend,0)*100,2
    ) AS top_3_supplier_concentration_pct,
    ROUND(SUM(CASE WHEN spend_rank<=5 THEN procurement_spend ELSE 0 END),2)
        AS top_5_supplier_spend,
    ROUND(
        SUM(CASE WHEN spend_rank<=5 THEN procurement_spend ELSE 0 END) /
        NULLIF(total_procurement_spend,0)*100,2
    ) AS top_5_supplier_concentration_pct,
    ROUND(SUM(CASE WHEN spend_rank<=10 THEN procurement_spend ELSE 0 END),2)
        AS top_10_supplier_spend,
    ROUND(
        SUM(CASE WHEN spend_rank<=10 THEN procurement_spend ELSE 0 END) /
        NULLIF(total_procurement_spend,0)*100,2
    ) AS top_10_supplier_concentration_pct
FROM ranked_suppliers
CROSS JOIN company_spend
GROUP BY total_procurement_spend;


/* SECTION 8 — CATEGORY PROCUREMENT PERFORMANCE */
WITH category_procurement AS (
    SELECT
        c.CategoryID,
        c.CategoryName,
        SUM(poi.LineTotal) AS procurement_spend,
        SUM(poi.QuantityOrdered) AS units_procured,
        COUNT(DISTINCT po.PurchaseOrderID) AS purchase_orders,
        COUNT(DISTINCT po.SupplierID) AS active_suppliers
    FROM PurchaseOrders po
    JOIN PurchaseOrderItems poi ON po.PurchaseOrderID = poi.PurchaseOrderID
    JOIN Products p ON poi.ProductID = p.ProductID
    JOIN Categories c ON p.CategoryID = c.CategoryID
    GROUP BY c.CategoryID, c.CategoryName
),
company_spend AS (
    SELECT SUM(procurement_spend) AS total_procurement_spend
    FROM category_procurement
)
SELECT
    cp.CategoryID,
    cp.CategoryName,
    ROUND(cp.procurement_spend,2) AS procurement_spend,
    cp.units_procured,
    cp.purchase_orders,
    cp.active_suppliers,
    ROUND(cp.procurement_spend/NULLIF(cp.units_procured,0),2)
        AS average_procurement_unit_cost,
    ROUND(cp.procurement_spend/NULLIF(cs.total_procurement_spend,0)*100,2)
        AS procurement_spend_share_pct
FROM category_procurement cp
CROSS JOIN company_spend cs
ORDER BY cp.procurement_spend DESC;


/* SECTION 9 — ANNUAL CATEGORY PROCUREMENT COST */
SELECT
    YEAR(po.PurchaseOrderDate) AS procurement_year,
    c.CategoryName,
    ROUND(SUM(poi.LineTotal),2) AS procurement_spend,
    SUM(poi.QuantityOrdered) AS units_procured,
    ROUND(
        SUM(poi.LineTotal)/NULLIF(SUM(poi.QuantityOrdered),0),2
    ) AS average_procurement_unit_cost
FROM PurchaseOrders po
JOIN PurchaseOrderItems poi ON po.PurchaseOrderID = poi.PurchaseOrderID
JOIN Products p ON poi.ProductID = p.ProductID
JOIN Categories c ON p.CategoryID = c.CategoryID
GROUP BY YEAR(po.PurchaseOrderDate), c.CategoryName
ORDER BY procurement_year, procurement_spend DESC;


/* SECTION 10 — PRODUCT PROCUREMENT COST TRENDS */
SELECT
    YEAR(po.PurchaseOrderDate) AS procurement_year,
    p.ProductID,
    p.ProductName,
    c.CategoryName,
    SUM(poi.QuantityOrdered) AS units_procured,
    ROUND(SUM(poi.LineTotal),2) AS procurement_spend,
    ROUND(
        SUM(poi.LineTotal)/NULLIF(SUM(poi.QuantityOrdered),0),2
    ) AS weighted_average_unit_cost
FROM PurchaseOrders po
JOIN PurchaseOrderItems poi ON po.PurchaseOrderID = poi.PurchaseOrderID
JOIN Products p ON poi.ProductID = p.ProductID
JOIN Categories c ON p.CategoryID = c.CategoryID
GROUP BY
    YEAR(po.PurchaseOrderDate),
    p.ProductID,
    p.ProductName,
    c.CategoryName
ORDER BY p.ProductID, procurement_year;


/* SECTION 11 — SUPPLIER DELIVERY PERFORMANCE */
SELECT
    s.SupplierID,
    s.SupplierName,
    COUNT(po.PurchaseOrderID) AS delivered_purchase_orders,
    SUM(CASE WHEN po.ActualDeliveryDate<=po.ExpectedDeliveryDate THEN 1 ELSE 0 END)
        AS on_time_purchase_orders,
    SUM(CASE WHEN po.ActualDeliveryDate>po.ExpectedDeliveryDate THEN 1 ELSE 0 END)
        AS late_purchase_orders,
    ROUND(
        SUM(CASE WHEN po.ActualDeliveryDate<=po.ExpectedDeliveryDate THEN 1 ELSE 0 END) /
        NULLIF(COUNT(po.PurchaseOrderID),0)*100,2
    ) AS supplier_on_time_delivery_rate_pct,
    ROUND(AVG(DATEDIFF(po.ActualDeliveryDate,po.PurchaseOrderDate)),2)
        AS avg_actual_lead_time_days,
    ROUND(AVG(DATEDIFF(po.ExpectedDeliveryDate,po.PurchaseOrderDate)),2)
        AS avg_expected_lead_time_days,
    ROUND(AVG(DATEDIFF(po.ActualDeliveryDate,po.ExpectedDeliveryDate)),2)
        AS avg_delivery_variance_days
FROM Suppliers s
JOIN PurchaseOrders po ON s.SupplierID = po.SupplierID
WHERE po.ActualDeliveryDate IS NOT NULL
GROUP BY s.SupplierID, s.SupplierName
ORDER BY supplier_on_time_delivery_rate_pct DESC, avg_delivery_variance_days ASC;


/* SECTION 12 — ANNUAL SUPPLIER DELIVERY PERFORMANCE */
SELECT
    YEAR(po.PurchaseOrderDate) AS procurement_year,
    s.SupplierID,
    s.SupplierName,
    COUNT(po.PurchaseOrderID) AS delivered_purchase_orders,
    ROUND(
        SUM(CASE WHEN po.ActualDeliveryDate<=po.ExpectedDeliveryDate THEN 1 ELSE 0 END) /
        NULLIF(COUNT(po.PurchaseOrderID),0)*100,2
    ) AS supplier_on_time_delivery_rate_pct,
    ROUND(AVG(DATEDIFF(po.ActualDeliveryDate,po.PurchaseOrderDate)),2)
        AS avg_actual_lead_time_days,
    ROUND(AVG(DATEDIFF(po.ActualDeliveryDate,po.ExpectedDeliveryDate)),2)
        AS avg_delivery_variance_days
FROM PurchaseOrders po
JOIN Suppliers s ON po.SupplierID = s.SupplierID
WHERE po.ActualDeliveryDate IS NOT NULL
GROUP BY YEAR(po.PurchaseOrderDate), s.SupplierID, s.SupplierName
ORDER BY procurement_year, supplier_on_time_delivery_rate_pct DESC;


/* SECTION 13 — SUPPLIER PRODUCT PORTFOLIO */
SELECT
    s.SupplierID,
    s.SupplierName,
    COUNT(DISTINCT p.ProductID) AS products_supplied,
    COUNT(DISTINCT c.CategoryID) AS categories_supplied,
    GROUP_CONCAT(
        DISTINCT c.CategoryName
        ORDER BY c.CategoryName
        SEPARATOR ', '
    ) AS categories_supported,
    ROUND(SUM(poi.LineTotal),2) AS procurement_spend
FROM Suppliers s
JOIN PurchaseOrders po ON s.SupplierID = po.SupplierID
JOIN PurchaseOrderItems poi ON po.PurchaseOrderID = poi.PurchaseOrderID
JOIN Products p ON poi.ProductID = p.ProductID
JOIN Categories c ON p.CategoryID = c.CategoryID
GROUP BY s.SupplierID, s.SupplierName
ORDER BY products_supplied DESC, procurement_spend DESC;


/* SECTION 14 — CATEGORY SUPPLIER DEPENDENCY */
WITH supplier_category_spend AS (
    SELECT
        c.CategoryID,
        c.CategoryName,
        s.SupplierID,
        s.SupplierName,
        SUM(poi.LineTotal) AS supplier_category_spend
    FROM PurchaseOrders po
    JOIN PurchaseOrderItems poi ON po.PurchaseOrderID = poi.PurchaseOrderID
    JOIN Suppliers s ON po.SupplierID = s.SupplierID
    JOIN Products p ON poi.ProductID = p.ProductID
    JOIN Categories c ON p.CategoryID = c.CategoryID
    GROUP BY c.CategoryID, c.CategoryName, s.SupplierID, s.SupplierName
),
category_total AS (
    SELECT
        CategoryID,
        SUM(supplier_category_spend) AS category_procurement_spend
    FROM supplier_category_spend
    GROUP BY CategoryID
)
SELECT
    scs.CategoryID,
    scs.CategoryName,
    scs.SupplierID,
    scs.SupplierName,
    ROUND(scs.supplier_category_spend,2) AS supplier_category_spend,
    ROUND(
        scs.supplier_category_spend /
        NULLIF(ct.category_procurement_spend,0)*100,2
    ) AS category_supplier_dependency_pct
FROM supplier_category_spend scs
JOIN category_total ct ON scs.CategoryID = ct.CategoryID
ORDER BY scs.CategoryName, category_supplier_dependency_pct DESC;


/* SECTION 15 — TOP SUPPLIER DEPENDENCY PER CATEGORY */
WITH supplier_category_spend AS (
    SELECT
        c.CategoryID,
        c.CategoryName,
        s.SupplierID,
        s.SupplierName,
        SUM(poi.LineTotal) AS supplier_category_spend
    FROM PurchaseOrders po
    JOIN PurchaseOrderItems poi ON po.PurchaseOrderID = poi.PurchaseOrderID
    JOIN Suppliers s ON po.SupplierID = s.SupplierID
    JOIN Products p ON poi.ProductID = p.ProductID
    JOIN Categories c ON p.CategoryID = c.CategoryID
    GROUP BY c.CategoryID, c.CategoryName, s.SupplierID, s.SupplierName
),
category_total AS (
    SELECT
        CategoryID,
        SUM(supplier_category_spend) AS category_procurement_spend
    FROM supplier_category_spend
    GROUP BY CategoryID
),
ranked_dependency AS (
    SELECT
        scs.*,
        scs.supplier_category_spend /
        NULLIF(ct.category_procurement_spend,0)*100 AS dependency_pct,
        ROW_NUMBER() OVER (
            PARTITION BY scs.CategoryID
            ORDER BY scs.supplier_category_spend DESC
        ) AS dependency_rank
    FROM supplier_category_spend scs
    JOIN category_total ct ON scs.CategoryID = ct.CategoryID
)
SELECT
    CategoryID,
    CategoryName,
    SupplierID,
    SupplierName,
    ROUND(supplier_category_spend,2) AS supplier_category_spend,
    ROUND(dependency_pct,2) AS top_supplier_dependency_pct
FROM ranked_dependency
WHERE dependency_rank = 1
ORDER BY top_supplier_dependency_pct DESC;


/* SECTION 16 — PROCUREMENT SPEND RECONCILIATION */
WITH supplier_spend AS (
    SELECT
        po.SupplierID,
        SUM(poi.LineTotal) AS supplier_procurement_spend
    FROM PurchaseOrders po
    JOIN PurchaseOrderItems poi ON po.PurchaseOrderID = poi.PurchaseOrderID
    GROUP BY po.SupplierID
),
company_spend AS (
    SELECT SUM(LineTotal) AS total_procurement_spend
    FROM PurchaseOrderItems
)
SELECT
    ROUND(SUM(ss.supplier_procurement_spend),2)
        AS sum_of_supplier_procurement_spend,
    ROUND(cs.total_procurement_spend,2)
        AS company_total_procurement_spend,
    ROUND(
        SUM(ss.supplier_procurement_spend)-cs.total_procurement_spend,2
    ) AS reconciliation_difference
FROM supplier_spend ss
CROSS JOIN company_spend cs
GROUP BY cs.total_procurement_spend;


/* SECTION 17 — CATEGORY PROCUREMENT SPEND RECONCILIATION */
WITH category_spend AS (
    SELECT
        p.CategoryID,
        SUM(poi.LineTotal) AS category_procurement_spend
    FROM PurchaseOrderItems poi
    JOIN Products p ON poi.ProductID = p.ProductID
    GROUP BY p.CategoryID
),
company_spend AS (
    SELECT SUM(LineTotal) AS total_procurement_spend
    FROM PurchaseOrderItems
)
SELECT
    ROUND(SUM(cs.category_procurement_spend),2)
        AS sum_of_category_procurement_spend,
    ROUND(company.total_procurement_spend,2)
        AS company_total_procurement_spend,
    ROUND(
        SUM(cs.category_procurement_spend)-company.total_procurement_spend,2
    ) AS reconciliation_difference
FROM category_spend cs
CROSS JOIN company_spend company
GROUP BY company.total_procurement_spend;


/* SECTION 18 — PURCHASE ORDER TOTAL RECONCILIATION */
WITH line_totals AS (
    SELECT
        PurchaseOrderID,
        SUM(LineTotal) AS calculated_po_total
    FROM PurchaseOrderItems
    GROUP BY PurchaseOrderID
)
SELECT
    ROUND(SUM(lt.calculated_po_total),2)
        AS sum_of_purchase_order_item_totals,
    ROUND(SUM(po.TotalAmount),2)
        AS sum_of_purchase_order_header_totals,
    ROUND(
        SUM(lt.calculated_po_total)-SUM(po.TotalAmount),2
    ) AS reconciliation_difference
FROM PurchaseOrders po
JOIN line_totals lt ON po.PurchaseOrderID = lt.PurchaseOrderID;


/* SECTION 19 — SUPPLIER DELIVERY CONTROL RECONCILIATION */
WITH supplier_po_counts AS (
    SELECT
        SupplierID,
        COUNT(*) AS supplier_purchase_orders
    FROM PurchaseOrders
    GROUP BY SupplierID
),
company_po_count AS (
    SELECT COUNT(*) AS company_purchase_orders
    FROM PurchaseOrders
)
SELECT
    SUM(spc.supplier_purchase_orders)
        AS sum_of_supplier_purchase_orders,
    cpc.company_purchase_orders
        AS company_purchase_orders,
    SUM(spc.supplier_purchase_orders)-cpc.company_purchase_orders
        AS reconciliation_difference
FROM supplier_po_counts spc
CROSS JOIN company_po_count cpc
GROUP BY cpc.company_purchase_orders;


/* ============================================================
   END OF PHASE 6D.4 — VERSION 1.0
   ============================================================ */
