/* ============================================================
   NOVAMART CONSUMER GOODS LIMITED
   SUPPLY CHAIN INTELLIGENCE PLATFORM

   PHASE 6D.6 — FINANCIAL & OPERATIONAL EFFICIENCY

   Module:
       06_financial_operational_efficiency.sql

   Version:
       1.1

   Database:
       novamart_supply_chain

   Platform:
       MySQL 8.0+

   Analysis Period:
       2023–2025

   Purpose:
       Evaluate how effectively NovaMart converts commercial
       activity into cash collection and operational performance,
       while controlling procurement and logistics cost exposure.

   Primary Business Questions:
       1. How efficiently is revenue converting into collected cash?
       2. How have revenue, procurement spend and transport cost
          changed relative to one another?
       3. What share of revenue is consumed by logistics cost?
       4. Which warehouses generate revenue most efficiently
          relative to transport cost?
       5. What payment methods and payment statuses dominate?
       6. Where is payment exposure concentrated?
       7. What is NovaMart's 2025 estimated gross profit after
          applying the approved StandardCost proxy?
       8. What is the 2025 estimated contribution after transport?
       9. Which categories generate the strongest 2025 estimated
          gross-profit contribution?
       10. Where are the major financial and operational
           efficiency pressures?

   Core Definitions:
       Revenue
           = SUM(SalesOrderItems.LineTotal)

       Collected Cash
           = SUM(Payments.AmountPaid)
             WHERE PaymentStatus = 'Paid'

       Collection Rate
           = Collected Cash / Revenue * 100

       Procurement Spend
           = SUM(PurchaseOrderItems.LineTotal)

       Transport Cost
           = SUM(Shipments.TransportCost)

       Transport Cost Ratio
           = Transport Cost / Revenue * 100

       Procurement Spend Intensity
           = Procurement Spend / Revenue * 100

       2025 Estimated COGS
           = SUM(2025 QuantitySold * Products.StandardCost)

       2025 Estimated Gross Profit
           = 2025 Revenue - 2025 Estimated COGS

       2025 Estimated Gross Margin %
           = 2025 Estimated Gross Profit / 2025 Revenue * 100

       2025 Estimated Contribution After Transport
           = 2025 Estimated Gross Profit - 2025 Transport Cost

       2025 Estimated Contribution Margin %
           = Estimated Contribution After Transport / Revenue * 100

   Methodological Governance:
       - Revenue, payments, procurement and logistics are separate
         fact domains and must be aggregated independently before
         being combined.
       - Only PaymentStatus = 'Paid' is treated as collected cash.
       - Pending and Failed payment records are not counted as
         collected cash.
       - Procurement spend is NOT treated as COGS or operating
         expense. It is analysed as procurement resource intensity
         because purchases can build inventory.
       - Transport cost is a direct logistics cost, but it is not
         the full operating-cost base.
       - Therefore, "Estimated Contribution After Transport" is
         NOT net profit or operating profit.
       - Current Products.StandardCost is used only for 2025
         estimated COGS/gross-profit analysis, consistent with
         the approved Phase 6D.2 methodology.
       - Historical 2023–2024 gross margin is not inferred.
       - Category-level transport cost is NOT allocated because
         Phase 6D.5 showed shipment weight has only a weak
         relationship with transport cost. Category analysis
         therefore stops at estimated gross profit/margin.
       - Warehouse-level contribution after transport remains
         valid because transport cost is directly recorded at
         shipment/warehouse grain.
       - Payment lag is measured from OrderDate to PaymentDate and
         is not receivables aging because formal due dates are
         unavailable.
       - All ratios must preserve compatible grains and periods.

   Source Tables:
       SalesOrders
       SalesOrderItems
       Payments
       Shipments
       PurchaseOrders
       PurchaseOrderItems
       Products
       Categories
       Customers
       Warehouses

   ============================================================ */

USE novamart_supply_chain;


/* ============================================================
   SECTION 1
   COMPANY FINANCIAL & OPERATING SUMMARY
   ============================================================ */

WITH revenue AS (
    SELECT SUM(LineTotal) AS total_revenue
    FROM SalesOrderItems
),

payments AS (
    SELECT SUM(AmountPaid) AS total_collected_cash
    FROM Payments
    WHERE PaymentStatus = 'Paid'
),

procurement AS (
    SELECT SUM(LineTotal) AS total_procurement_spend
    FROM PurchaseOrderItems
),

logistics AS (
    SELECT SUM(TransportCost) AS total_transport_cost
    FROM Shipments
)

SELECT
    ROUND(r.total_revenue,2) AS total_revenue,
    ROUND(p.total_collected_cash,2) AS total_collected_cash,
    ROUND(pr.total_procurement_spend,2) AS total_procurement_spend,
    ROUND(l.total_transport_cost,2) AS total_transport_cost,

    ROUND(
        p.total_collected_cash
        / NULLIF(r.total_revenue,0)
        * 100,
        2
    ) AS collection_rate_pct,

    ROUND(
        l.total_transport_cost
        / NULLIF(r.total_revenue,0)
        * 100,
        2
    ) AS transport_cost_ratio_pct,

    ROUND(
        pr.total_procurement_spend
        / NULLIF(r.total_revenue,0)
        * 100,
        2
    ) AS procurement_spend_intensity_pct

FROM revenue r
CROSS JOIN payments p
CROSS JOIN procurement pr
CROSS JOIN logistics l;


/* ============================================================
   SECTION 2
   ANNUAL FINANCIAL & OPERATING PERFORMANCE
   ============================================================ */

WITH annual_revenue AS (
    SELECT
        YEAR(so.OrderDate) AS analysis_year,
        SUM(soi.LineTotal) AS revenue,
        COUNT(DISTINCT so.SalesOrderID) AS sales_orders
    FROM SalesOrders so
    JOIN SalesOrderItems soi
        ON so.SalesOrderID = soi.SalesOrderID
    GROUP BY YEAR(so.OrderDate)
),

annual_payments AS (
    SELECT
        YEAR(so.OrderDate) AS analysis_year,
        SUM(py.AmountPaid) AS collected_cash
    FROM Payments py
    JOIN SalesOrders so
        ON py.SalesOrderID = so.SalesOrderID
    WHERE py.PaymentStatus = 'Paid'
    GROUP BY YEAR(so.OrderDate)
),

annual_procurement AS (
    SELECT
        YEAR(po.PurchaseOrderDate) AS analysis_year,
        SUM(poi.LineTotal) AS procurement_spend
    FROM PurchaseOrders po
    JOIN PurchaseOrderItems poi
        ON po.PurchaseOrderID = poi.PurchaseOrderID
    GROUP BY YEAR(po.PurchaseOrderDate)
),

annual_transport AS (
    SELECT
        YEAR(so.OrderDate) AS analysis_year,
        SUM(sh.TransportCost) AS transport_cost
    FROM Shipments sh
    JOIN SalesOrders so
        ON sh.SalesOrderID = so.SalesOrderID
    GROUP BY YEAR(so.OrderDate)
)

SELECT
    ar.analysis_year,
    ROUND(ar.revenue,2) AS revenue,
    ar.sales_orders,
    ROUND(ap.collected_cash,2) AS collected_cash,
    ROUND(ac.procurement_spend,2) AS procurement_spend,
    ROUND(at.transport_cost,2) AS transport_cost,

    ROUND(
        ap.collected_cash
        / NULLIF(ar.revenue,0)
        * 100,
        2
    ) AS collection_rate_pct,

    ROUND(
        at.transport_cost
        / NULLIF(ar.revenue,0)
        * 100,
        2
    ) AS transport_cost_ratio_pct,

    ROUND(
        ac.procurement_spend
        / NULLIF(ar.revenue,0)
        * 100,
        2
    ) AS procurement_spend_intensity_pct

FROM annual_revenue ar
JOIN annual_payments ap
    ON ar.analysis_year = ap.analysis_year
JOIN annual_procurement ac
    ON ar.analysis_year = ac.analysis_year
JOIN annual_transport at
    ON ar.analysis_year = at.analysis_year
ORDER BY ar.analysis_year;


/* ============================================================
   SECTION 3
   ANNUAL REVENUE VS COST GROWTH
   ============================================================ */

WITH annual_metrics AS (

    SELECT
        ar.analysis_year,
        ar.revenue,
        ap.procurement_spend,
        at.transport_cost

    FROM (
        SELECT
            YEAR(so.OrderDate) AS analysis_year,
            SUM(soi.LineTotal) AS revenue
        FROM SalesOrders so
        JOIN SalesOrderItems soi
            ON so.SalesOrderID = soi.SalesOrderID
        GROUP BY YEAR(so.OrderDate)
    ) ar

    JOIN (
        SELECT
            YEAR(po.PurchaseOrderDate) AS analysis_year,
            SUM(poi.LineTotal) AS procurement_spend
        FROM PurchaseOrders po
        JOIN PurchaseOrderItems poi
            ON po.PurchaseOrderID = poi.PurchaseOrderID
        GROUP BY YEAR(po.PurchaseOrderDate)
    ) ap
        ON ar.analysis_year = ap.analysis_year

    JOIN (
        SELECT
            YEAR(so.OrderDate) AS analysis_year,
            SUM(sh.TransportCost) AS transport_cost
        FROM Shipments sh
        JOIN SalesOrders so
            ON sh.SalesOrderID = so.SalesOrderID
        GROUP BY YEAR(so.OrderDate)
    ) at
        ON ar.analysis_year = at.analysis_year
),

growth AS (
    SELECT
        *,
        LAG(revenue) OVER (ORDER BY analysis_year) AS prior_revenue,
        LAG(procurement_spend) OVER (ORDER BY analysis_year) AS prior_procurement_spend,
        LAG(transport_cost) OVER (ORDER BY analysis_year) AS prior_transport_cost
    FROM annual_metrics
)

SELECT
    analysis_year,

    ROUND(
        (revenue-prior_revenue)
        / NULLIF(prior_revenue,0)
        * 100,
        2
    ) AS revenue_growth_pct,

    ROUND(
        (procurement_spend-prior_procurement_spend)
        / NULLIF(prior_procurement_spend,0)
        * 100,
        2
    ) AS procurement_spend_growth_pct,

    ROUND(
        (transport_cost-prior_transport_cost)
        / NULLIF(prior_transport_cost,0)
        * 100,
        2
    ) AS transport_cost_growth_pct

FROM growth
ORDER BY analysis_year;


/* ============================================================
   SECTION 4
   PAYMENT STATUS PERFORMANCE
   ============================================================ */

WITH payment_status AS (
    SELECT
        PaymentStatus,
        COUNT(*) AS payment_records,
        SUM(AmountPaid) AS amount_paid
    FROM Payments
    GROUP BY PaymentStatus
),

company_payments AS (
    SELECT SUM(AmountPaid) AS company_amount_paid
    FROM Payments
)

SELECT
    ps.PaymentStatus,
    ps.payment_records,
    ROUND(ps.amount_paid,2) AS amount_paid,

    ROUND(
        ps.amount_paid
        / NULLIF(cp.company_amount_paid,0)
        * 100,
        2
    ) AS payment_value_share_pct,

    CASE
        WHEN ps.PaymentStatus = 'Paid'
        THEN 'Collected'
        ELSE 'Not Collected'
    END AS collection_treatment

FROM payment_status ps
CROSS JOIN company_payments cp
ORDER BY ps.amount_paid DESC;


/* ============================================================
   SECTION 5
   PAYMENT METHOD PERFORMANCE
   ============================================================ */

WITH payment_method AS (
    SELECT
        PaymentMethod,
        COUNT(*) AS paid_payment_records,
        SUM(AmountPaid) AS collected_cash
    FROM Payments
    WHERE PaymentStatus = 'Paid'
    GROUP BY PaymentMethod
),

company_payments AS (
    SELECT SUM(AmountPaid) AS total_collected_cash
    FROM Payments
    WHERE PaymentStatus = 'Paid'
)

SELECT
    pm.PaymentMethod,
    pm.paid_payment_records,
    ROUND(pm.collected_cash,2) AS collected_cash,

    ROUND(
        pm.collected_cash
        / NULLIF(cp.total_collected_cash,0)
        * 100,
        2
    ) AS collected_cash_share_pct,

    ROUND(
        pm.collected_cash
        / NULLIF(pm.paid_payment_records,0),
        2
    ) AS average_paid_payment_value

FROM payment_method pm
CROSS JOIN company_payments cp
ORDER BY pm.collected_cash DESC;


/* ============================================================
   SECTION 6
   ANNUAL CASH COLLECTION
   ============================================================ */

WITH annual_sales AS (
    SELECT
        YEAR(OrderDate) AS analysis_year,
        SUM(TotalAmount) AS sales_order_value
    FROM SalesOrders
    GROUP BY YEAR(OrderDate)
),

annual_paid AS (
    SELECT
        YEAR(so.OrderDate) AS analysis_year,
        SUM(py.AmountPaid) AS collected_cash
    FROM Payments py
    JOIN SalesOrders so
        ON py.SalesOrderID = so.SalesOrderID
    WHERE py.PaymentStatus = 'Paid'
    GROUP BY YEAR(so.OrderDate)
)

SELECT
    s.analysis_year,
    ROUND(s.sales_order_value,2) AS sales_order_value,
    ROUND(p.collected_cash,2) AS collected_cash,

    ROUND(
        p.collected_cash
        / NULLIF(s.sales_order_value,0)
        * 100,
        2
    ) AS collection_rate_pct,

    ROUND(
        s.sales_order_value-p.collected_cash,
        2
    ) AS uncollected_value

FROM annual_sales s
JOIN annual_paid p
    ON s.analysis_year = p.analysis_year
ORDER BY s.analysis_year;


/* ============================================================
   SECTION 7
   CUSTOMER TYPE CASH COLLECTION
   ============================================================ */

WITH segment_sales AS (
    SELECT
        cu.CustomerType,
        SUM(so.TotalAmount) AS sales_order_value
    FROM SalesOrders so
    JOIN Customers cu
        ON so.CustomerID = cu.CustomerID
    GROUP BY cu.CustomerType
),

segment_paid AS (
    SELECT
        cu.CustomerType,
        SUM(py.AmountPaid) AS collected_cash
    FROM Payments py
    JOIN SalesOrders so
        ON py.SalesOrderID = so.SalesOrderID
    JOIN Customers cu
        ON so.CustomerID = cu.CustomerID
    WHERE py.PaymentStatus = 'Paid'
    GROUP BY cu.CustomerType
)

SELECT
    ss.CustomerType,
    ROUND(ss.sales_order_value,2) AS sales_order_value,
    ROUND(sp.collected_cash,2) AS collected_cash,

    ROUND(
        sp.collected_cash
        / NULLIF(ss.sales_order_value,0)
        * 100,
        2
    ) AS collection_rate_pct,

    ROUND(
        ss.sales_order_value-sp.collected_cash,
        2
    ) AS uncollected_value

FROM segment_sales ss
JOIN segment_paid sp
    ON ss.CustomerType = sp.CustomerType
ORDER BY collected_cash DESC;


/* ============================================================
   SECTION 8
   CUSTOMER PAYMENT EXPOSURE
   ============================================================ */

WITH customer_sales AS (
    SELECT
        cu.CustomerID,
        cu.CustomerName,
        cu.CustomerType,
        SUM(so.TotalAmount) AS sales_order_value
    FROM Customers cu
    JOIN SalesOrders so
        ON cu.CustomerID = so.CustomerID
    GROUP BY
        cu.CustomerID,
        cu.CustomerName,
        cu.CustomerType
),

customer_paid AS (
    SELECT
        so.CustomerID,
        SUM(py.AmountPaid) AS collected_cash
    FROM Payments py
    JOIN SalesOrders so
        ON py.SalesOrderID = so.SalesOrderID
    WHERE py.PaymentStatus = 'Paid'
    GROUP BY so.CustomerID
)

SELECT
    cs.CustomerID,
    cs.CustomerName,
    cs.CustomerType,
    ROUND(cs.sales_order_value,2) AS sales_order_value,
    ROUND(COALESCE(cp.collected_cash,0),2) AS collected_cash,

    ROUND(
        cs.sales_order_value-COALESCE(cp.collected_cash,0),
        2
    ) AS uncollected_value,

    ROUND(
        COALESCE(cp.collected_cash,0)
        / NULLIF(cs.sales_order_value,0)
        * 100,
        2
    ) AS collection_rate_pct

FROM customer_sales cs
LEFT JOIN customer_paid cp
    ON cs.CustomerID = cp.CustomerID
ORDER BY
    uncollected_value DESC,
    sales_order_value DESC
LIMIT 20;


/* ============================================================
   SECTION 9
   WAREHOUSE REVENUE VS TRANSPORT COST
   ============================================================ */

WITH warehouse_revenue AS (
    SELECT
        so.WarehouseID,
        SUM(soi.LineTotal) AS revenue,
        COUNT(DISTINCT so.SalesOrderID) AS sales_orders
    FROM SalesOrders so
    JOIN SalesOrderItems soi
        ON so.SalesOrderID = soi.SalesOrderID
    GROUP BY so.WarehouseID
),

warehouse_transport AS (
    SELECT
        WarehouseID,
        SUM(TransportCost) AS transport_cost,
        COUNT(*) AS shipments
    FROM Shipments
    GROUP BY WarehouseID
)

SELECT
    w.WarehouseID,
    w.WarehouseName,
    ROUND(wr.revenue,2) AS revenue,
    wr.sales_orders,
    ROUND(wt.transport_cost,2) AS transport_cost,
    wt.shipments,

    ROUND(
        wt.transport_cost
        / NULLIF(wr.revenue,0)
        * 100,
        2
    ) AS transport_cost_to_revenue_pct,

    ROUND(
        wr.revenue
        / NULLIF(wt.transport_cost,0),
        2
    ) AS revenue_per_transport_naira

FROM Warehouses w
JOIN warehouse_revenue wr
    ON w.WarehouseID = wr.WarehouseID
JOIN warehouse_transport wt
    ON w.WarehouseID = wt.WarehouseID
ORDER BY revenue_per_transport_naira DESC;


/* ============================================================
   SECTION 10
   ANNUAL WAREHOUSE REVENUE VS TRANSPORT COST
   ============================================================ */

WITH warehouse_revenue AS (
    SELECT
        YEAR(so.OrderDate) AS analysis_year,
        so.WarehouseID,
        SUM(soi.LineTotal) AS revenue
    FROM SalesOrders so
    JOIN SalesOrderItems soi
        ON so.SalesOrderID = soi.SalesOrderID
    GROUP BY
        YEAR(so.OrderDate),
        so.WarehouseID
),

warehouse_transport AS (
    SELECT
        YEAR(so.OrderDate) AS analysis_year,
        sh.WarehouseID,
        SUM(sh.TransportCost) AS transport_cost
    FROM Shipments sh
    JOIN SalesOrders so
        ON sh.SalesOrderID = so.SalesOrderID
    GROUP BY
        YEAR(so.OrderDate),
        sh.WarehouseID
)

SELECT
    wr.analysis_year,
    w.WarehouseName,
    ROUND(wr.revenue,2) AS revenue,
    ROUND(wt.transport_cost,2) AS transport_cost,

    ROUND(
        wt.transport_cost
        / NULLIF(wr.revenue,0)
        * 100,
        2
    ) AS transport_cost_to_revenue_pct,

    ROUND(
        wr.revenue
        / NULLIF(wt.transport_cost,0),
        2
    ) AS revenue_per_transport_naira

FROM warehouse_revenue wr
JOIN warehouse_transport wt
    ON wr.analysis_year = wt.analysis_year
   AND wr.WarehouseID = wt.WarehouseID
JOIN Warehouses w
    ON wr.WarehouseID = w.WarehouseID
ORDER BY
    wr.analysis_year,
    revenue_per_transport_naira DESC;


/* ============================================================
   SECTION 11
   2025 COMPANY ESTIMATED PROFITABILITY & CONTRIBUTION
   ============================================================ */

WITH sales_2025 AS (
    SELECT
        SUM(soi.LineTotal) AS revenue,
        SUM(
            soi.QuantitySold * p.StandardCost
        ) AS estimated_cogs
    FROM SalesOrders so
    JOIN SalesOrderItems soi
        ON so.SalesOrderID = soi.SalesOrderID
    JOIN Products p
        ON soi.ProductID = p.ProductID
    WHERE YEAR(so.OrderDate) = 2025
),

transport_2025 AS (
    SELECT
        SUM(sh.TransportCost) AS transport_cost
    FROM Shipments sh
    JOIN SalesOrders so
        ON sh.SalesOrderID = so.SalesOrderID
    WHERE YEAR(so.OrderDate) = 2025
)

SELECT
    ROUND(s.revenue,2) AS revenue_2025,
    ROUND(s.estimated_cogs,2) AS estimated_cogs_2025,

    ROUND(
        s.revenue-s.estimated_cogs,
        2
    ) AS estimated_gross_profit_2025,

    ROUND(
        (s.revenue-s.estimated_cogs)
        / NULLIF(s.revenue,0)
        * 100,
        2
    ) AS estimated_gross_margin_pct_2025,

    ROUND(t.transport_cost,2) AS transport_cost_2025,

    ROUND(
        s.revenue
        - s.estimated_cogs
        - t.transport_cost,
        2
    ) AS estimated_contribution_after_transport_2025,

    ROUND(
        (
            s.revenue
            - s.estimated_cogs
            - t.transport_cost
        )
        / NULLIF(s.revenue,0)
        * 100,
        2
    ) AS estimated_contribution_margin_pct_2025

FROM sales_2025 s
CROSS JOIN transport_2025 t;


/* ============================================================
   SECTION 12
   2025 CATEGORY ESTIMATED GROSS PROFIT
   ============================================================

   Important:
       No category transport-cost allocation is performed.
       Phase 6D.5 showed shipment weight is only weakly associated
       with transport cost, so allocating transport cost by weight
       would create a misleading category contribution metric.

   ============================================================ */

SELECT
    c.CategoryID,
    c.CategoryName,

    ROUND(
        SUM(soi.LineTotal),
        2
    ) AS revenue_2025,

    ROUND(
        SUM(
            soi.QuantitySold * p.StandardCost
        ),
        2
    ) AS estimated_cogs_2025,

    ROUND(
        SUM(soi.LineTotal)
        -
        SUM(
            soi.QuantitySold * p.StandardCost
        ),
        2
    ) AS estimated_gross_profit_2025,

    ROUND(
        (
            SUM(soi.LineTotal)
            -
            SUM(
                soi.QuantitySold * p.StandardCost
            )
        )
        / NULLIF(SUM(soi.LineTotal),0)
        * 100,
        2
    ) AS estimated_gross_margin_pct_2025

FROM SalesOrders so
JOIN SalesOrderItems soi
    ON so.SalesOrderID = soi.SalesOrderID
JOIN Products p
    ON soi.ProductID = p.ProductID
JOIN Categories c
    ON p.CategoryID = c.CategoryID

WHERE YEAR(so.OrderDate) = 2025

GROUP BY
    c.CategoryID,
    c.CategoryName

ORDER BY
    estimated_gross_profit_2025 DESC;


/* ============================================================
   SECTION 13
   2025 WAREHOUSE ESTIMATED CONTRIBUTION AFTER TRANSPORT
   ============================================================ */

WITH warehouse_sales AS (
    SELECT
        so.WarehouseID,
        SUM(soi.LineTotal) AS revenue,
        SUM(
            soi.QuantitySold * p.StandardCost
        ) AS estimated_cogs
    FROM SalesOrders so
    JOIN SalesOrderItems soi
        ON so.SalesOrderID = soi.SalesOrderID
    JOIN Products p
        ON soi.ProductID = p.ProductID
    WHERE YEAR(so.OrderDate) = 2025
    GROUP BY so.WarehouseID
),

warehouse_transport AS (
    SELECT
        sh.WarehouseID,
        SUM(sh.TransportCost) AS transport_cost
    FROM Shipments sh
    JOIN SalesOrders so
        ON sh.SalesOrderID = so.SalesOrderID
    WHERE YEAR(so.OrderDate) = 2025
    GROUP BY sh.WarehouseID
)

SELECT
    w.WarehouseID,
    w.WarehouseName,

    ROUND(ws.revenue,2) AS revenue_2025,
    ROUND(ws.estimated_cogs,2) AS estimated_cogs_2025,

    ROUND(
        ws.revenue-ws.estimated_cogs,
        2
    ) AS estimated_gross_profit_2025,

    ROUND(wt.transport_cost,2) AS transport_cost_2025,

    ROUND(
        ws.revenue
        - ws.estimated_cogs
        - wt.transport_cost,
        2
    ) AS estimated_contribution_after_transport_2025,

    ROUND(
        (
            ws.revenue
            - ws.estimated_cogs
            - wt.transport_cost
        )
        / NULLIF(ws.revenue,0)
        * 100,
        2
    ) AS estimated_contribution_margin_pct_2025

FROM warehouse_sales ws
JOIN warehouse_transport wt
    ON ws.WarehouseID = wt.WarehouseID
JOIN Warehouses w
    ON ws.WarehouseID = w.WarehouseID

ORDER BY
    estimated_contribution_after_transport_2025 DESC;


/* ============================================================
   SECTION 14
   2025 CUSTOMER TYPE VALUE & COLLECTION
   ============================================================ */

WITH customer_sales AS (
    SELECT
        cu.CustomerType,
        SUM(so.TotalAmount) AS sales_order_value,
        COUNT(DISTINCT so.SalesOrderID) AS sales_orders
    FROM SalesOrders so
    JOIN Customers cu
        ON so.CustomerID = cu.CustomerID
    WHERE YEAR(so.OrderDate) = 2025
    GROUP BY cu.CustomerType
),

customer_payments AS (
    SELECT
        cu.CustomerType,
        SUM(py.AmountPaid) AS collected_cash
    FROM Payments py
    JOIN SalesOrders so
        ON py.SalesOrderID = so.SalesOrderID
    JOIN Customers cu
        ON so.CustomerID = cu.CustomerID
    WHERE YEAR(so.OrderDate) = 2025
      AND py.PaymentStatus = 'Paid'
    GROUP BY cu.CustomerType
)

SELECT
    cs.CustomerType,
    ROUND(cs.sales_order_value,2) AS sales_order_value_2025,
    cs.sales_orders,
    ROUND(cp.collected_cash,2) AS collected_cash_2025,

    ROUND(
        cp.collected_cash
        / NULLIF(cs.sales_order_value,0)
        * 100,
        2
    ) AS collection_rate_pct_2025,

    ROUND(
        cs.sales_order_value
        / NULLIF(cs.sales_orders,0),
        2
    ) AS average_order_value_2025

FROM customer_sales cs
JOIN customer_payments cp
    ON cs.CustomerType = cp.CustomerType

ORDER BY sales_order_value_2025 DESC;


/* ============================================================
   SECTION 15
   PAYMENT TIMING SUMMARY — PAID PAYMENTS ONLY
   ============================================================ */

SELECT
    ROUND(
        AVG(
            DATEDIFF(
                py.PaymentDate,
                so.OrderDate
            )
        ),
        2
    ) AS avg_paid_payment_lag_days,

    MIN(
        DATEDIFF(
            py.PaymentDate,
            so.OrderDate
        )
    ) AS min_paid_payment_lag_days,

    MAX(
        DATEDIFF(
            py.PaymentDate,
            so.OrderDate
        )
    ) AS max_paid_payment_lag_days

FROM Payments py
JOIN SalesOrders so
    ON py.SalesOrderID = so.SalesOrderID

WHERE py.PaymentStatus = 'Paid';


/* ============================================================
   SECTION 16
   ANNUAL PAYMENT TIMING — PAID PAYMENTS ONLY
   ============================================================ */

SELECT
    YEAR(so.OrderDate) AS analysis_year,

    ROUND(
        AVG(
            DATEDIFF(
                py.PaymentDate,
                so.OrderDate
            )
        ),
        2
    ) AS avg_paid_payment_lag_days

FROM Payments py
JOIN SalesOrders so
    ON py.SalesOrderID = so.SalesOrderID

WHERE py.PaymentStatus = 'Paid'

GROUP BY YEAR(so.OrderDate)
ORDER BY analysis_year;


/* ============================================================
   SECTION 17
   REVENUE COLLECTION RECONCILIATION
   ============================================================ */

WITH sales_value AS (
    SELECT
        SUM(TotalAmount) AS sales_order_value
    FROM SalesOrders
),

paid_value AS (
    SELECT
        SUM(AmountPaid) AS collected_cash
    FROM Payments
    WHERE PaymentStatus = 'Paid'
)

SELECT
    ROUND(sv.sales_order_value,2) AS sales_order_value,
    ROUND(pv.collected_cash,2) AS collected_cash,

    ROUND(
        sv.sales_order_value-pv.collected_cash,
        2
    ) AS uncollected_value,

    ROUND(
        pv.collected_cash
        / NULLIF(sv.sales_order_value,0)
        * 100,
        2
    ) AS collection_rate_pct

FROM sales_value sv
CROSS JOIN paid_value pv;


/* ============================================================
   SECTION 18
   SALES HEADER VS LINE REVENUE RECONCILIATION
   ============================================================ */

WITH line_revenue AS (
    SELECT
        SalesOrderID,
        SUM(LineTotal) AS calculated_order_total
    FROM SalesOrderItems
    GROUP BY SalesOrderID
)

SELECT
    ROUND(
        SUM(lr.calculated_order_total),
        2
    ) AS sum_of_sales_line_totals,

    ROUND(
        SUM(so.TotalAmount),
        2
    ) AS sum_of_sales_order_totals,

    ROUND(
        SUM(lr.calculated_order_total)
        - SUM(so.TotalAmount),
        2
    ) AS reconciliation_difference

FROM SalesOrders so
JOIN line_revenue lr
    ON so.SalesOrderID = lr.SalesOrderID;


/* ============================================================
   SECTION 19
   2025 ESTIMATED CONTRIBUTION RECONCILIATION
   ============================================================ */

WITH company_value AS (
    SELECT
        SUM(soi.LineTotal) AS revenue,
        SUM(
            soi.QuantitySold * p.StandardCost
        ) AS estimated_cogs
    FROM SalesOrders so
    JOIN SalesOrderItems soi
        ON so.SalesOrderID = soi.SalesOrderID
    JOIN Products p
        ON soi.ProductID = p.ProductID
    WHERE YEAR(so.OrderDate) = 2025
),

company_transport AS (
    SELECT
        SUM(sh.TransportCost) AS transport_cost
    FROM Shipments sh
    JOIN SalesOrders so
        ON sh.SalesOrderID = so.SalesOrderID
    WHERE YEAR(so.OrderDate) = 2025
)

SELECT
    ROUND(cv.revenue,2) AS revenue_2025,
    ROUND(cv.estimated_cogs,2) AS estimated_cogs_2025,
    ROUND(ct.transport_cost,2) AS transport_cost_2025,

    ROUND(
        cv.revenue
        - cv.estimated_cogs
        - ct.transport_cost,
        2
    ) AS estimated_contribution_after_transport_2025

FROM company_value cv
CROSS JOIN company_transport ct;


/* ============================================================
   SECTION 20
   DOMAIN TOTAL CONTROL
   ============================================================ */

SELECT
    (SELECT COUNT(*) FROM SalesOrders)
        AS sales_orders,

    (SELECT COUNT(*) FROM Payments)
        AS payments,

    (SELECT COUNT(*) FROM Shipments)
        AS shipments,

    (SELECT COUNT(*) FROM PurchaseOrders)
        AS purchase_orders,

    (SELECT COUNT(*) FROM SalesOrderItems)
        AS sales_order_items,

    (SELECT COUNT(*) FROM PurchaseOrderItems)
        AS purchase_order_items;


/* ============================================================
   END OF PHASE 6D.6 — VERSION 1.1
   ============================================================ */
