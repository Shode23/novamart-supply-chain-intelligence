/* ============================================================
   NOVAMART CONSUMER GOODS LIMITED
   SUPPLY CHAIN INTELLIGENCE PLATFORM

   PHASE 6D.3 — INVENTORY INTELLIGENCE

   Module:
       03_inventory_intelligence.sql

   Version:
       1.0

   Database:
       novamart_supply_chain

   Platform:
       MySQL 8.0+

   Analysis Period:
       2023–2025

   Purpose:
       Evaluate NovaMart's inventory position, stock-out
       behaviour, warehouse inventory distribution, demand
       alignment, inventory velocity and 2025 estimated
       inventory turnover.

   Primary Business Questions:
       1. Where are NovaMart's major stock-out risks?
       2. Which products appear slow-moving?
       3. Which warehouses carry the most inventory?
       4. Is current inventory aligned with demand?
       5. How have stock-out events changed over time?
       6. Which products/warehouses are below reorder or
          safety-stock thresholds?
       7. How efficiently is inventory turning in 2025?

   Core Definitions:
       Current Inventory Units
           = SUM(Inventory.QuantityOnHand)

       Current Inventory Value
           = SUM(Inventory.QuantityOnHand * Products.StandardCost)

       Stock-out Event
           = InventoryTransactions.TransactionType = 'Sales Shipment'
             AND StockAfter = 0

       Stock-out Event Rate
           = Stock-out Events / Sales Shipment Transactions * 100

       2025 Estimated COGS
           = SUM(2025 QuantitySold * Products.StandardCost)

       2025 Average Inventory Value
           = ((Opening Inventory Units + Closing Inventory Units) / 2)
             * Products.StandardCost,
             aggregated across product-warehouse pairs.

       2025 Estimated Inventory Turnover
           = 2025 Estimated COGS / 2025 Average Inventory Value

       2025 Estimated Days of Inventory
           = 365 / 2025 Estimated Inventory Turnover

       Current Days of Supply
           = Current QuantityOnHand /
             (2025 Units Sold / 365)

   Methodological Governance:
       - Inventory is analysed at product-warehouse grain where
         appropriate.
       - Stock-out logic uses the same definition validated in
         Phase 5C.
       - Historical profitability limitations established in
         Phase 6D.2 also apply to cost-based inventory metrics.
       - Therefore, cost-based turnover and days-of-inventory
         metrics are restricted to 2025.
       - Current StandardCost is used as an estimated cost basis,
         not an accounting valuation.
       - Current Inventory is a snapshot and must not be treated
         as historical inventory for 2023 or 2024.
       - Shipments and Payments are not joined into inventory
         fact calculations.
       - Avoid fact duplication by aggregating inventory and
         sales domains independently before joining them.

   Analytical Grains:
       Inventory snapshot grain: one row per product-warehouse pair
       Inventory transaction grain: one ledger transaction
       Product grain
       Warehouse grain
       Category grain
       Year grain

   Source Tables:
       Inventory
       InventoryTransactions
       Products
       Categories
       Warehouses
       SalesOrders
       SalesOrderItems

   ============================================================ */

USE novamart_supply_chain;


/* ============================================================
   SECTION 1
   CURRENT INVENTORY POSITION
   ============================================================

   Grain:
       Entire current inventory snapshot.

   Purpose:
       Establish the current inventory baseline.

   ============================================================ */

SELECT
    SUM(i.QuantityOnHand) AS current_inventory_units,

    ROUND(
        SUM(i.QuantityOnHand * p.StandardCost),
        2
    ) AS current_estimated_inventory_value,

    SUM(
        CASE
            WHEN i.QuantityOnHand <= i.ReorderLevel
            THEN 1 ELSE 0
        END
    ) AS product_warehouse_pairs_at_or_below_reorder,

    SUM(
        CASE
            WHEN i.QuantityOnHand <= i.SafetyStock
            THEN 1 ELSE 0
        END
    ) AS product_warehouse_pairs_at_or_below_safety_stock,

    SUM(
        CASE
            WHEN i.QuantityOnHand = 0
            THEN 1 ELSE 0
        END
    ) AS current_zero_stock_pairs,

    COUNT(*) AS total_product_warehouse_pairs

FROM Inventory AS i

INNER JOIN Products AS p
    ON i.ProductID = p.ProductID;


/* ============================================================
   SECTION 2
   CURRENT INVENTORY BY WAREHOUSE
   ============================================================

   Grain:
       One row per warehouse.

   Answers:
       - Which warehouse carries the most inventory?
       - What share of current inventory value is held by each
         warehouse?

   ============================================================ */

WITH warehouse_inventory AS (

    SELECT
        w.WarehouseID,
        w.WarehouseName,

        SUM(i.QuantityOnHand) AS inventory_units,

        SUM(
            i.QuantityOnHand * p.StandardCost
        ) AS estimated_inventory_value,

        SUM(
            CASE
                WHEN i.QuantityOnHand <= i.ReorderLevel
                THEN 1 ELSE 0
            END
        ) AS pairs_at_or_below_reorder,

        SUM(
            CASE
                WHEN i.QuantityOnHand <= i.SafetyStock
                THEN 1 ELSE 0
            END
        ) AS pairs_at_or_below_safety_stock,

        SUM(
            CASE
                WHEN i.QuantityOnHand = 0
                THEN 1 ELSE 0
            END
        ) AS zero_stock_pairs

    FROM Inventory AS i

    INNER JOIN Warehouses AS w
        ON i.WarehouseID = w.WarehouseID

    INNER JOIN Products AS p
        ON i.ProductID = p.ProductID

    GROUP BY
        w.WarehouseID,
        w.WarehouseName
),

company_inventory AS (

    SELECT
        SUM(estimated_inventory_value)
            AS company_inventory_value
    FROM warehouse_inventory
)

SELECT
    wi.WarehouseID,
    wi.WarehouseName,
    wi.inventory_units,

    ROUND(
        wi.estimated_inventory_value,
        2
    ) AS estimated_inventory_value,

    ROUND(
        wi.estimated_inventory_value
        / NULLIF(ci.company_inventory_value, 0)
        * 100,
        2
    ) AS inventory_value_share_pct,

    wi.pairs_at_or_below_reorder,
    wi.pairs_at_or_below_safety_stock,
    wi.zero_stock_pairs

FROM warehouse_inventory AS wi

CROSS JOIN company_inventory AS ci

ORDER BY
    wi.estimated_inventory_value DESC;


/* ============================================================
   SECTION 3
   CURRENT INVENTORY BY CATEGORY
   ============================================================

   Grain:
       One row per category.

   ============================================================ */

WITH category_inventory AS (

    SELECT
        c.CategoryID,
        c.CategoryName,

        SUM(i.QuantityOnHand) AS inventory_units,

        SUM(
            i.QuantityOnHand * p.StandardCost
        ) AS estimated_inventory_value

    FROM Inventory AS i

    INNER JOIN Products AS p
        ON i.ProductID = p.ProductID

    INNER JOIN Categories AS c
        ON p.CategoryID = c.CategoryID

    GROUP BY
        c.CategoryID,
        c.CategoryName
),

company_inventory AS (

    SELECT
        SUM(estimated_inventory_value)
            AS company_inventory_value
    FROM category_inventory
)

SELECT
    ci.CategoryID,
    ci.CategoryName,
    ci.inventory_units,

    ROUND(
        ci.estimated_inventory_value,
        2
    ) AS estimated_inventory_value,

    ROUND(
        ci.estimated_inventory_value
        / NULLIF(company.company_inventory_value, 0)
        * 100,
        2
    ) AS inventory_value_share_pct

FROM category_inventory AS ci

CROSS JOIN company_inventory AS company

ORDER BY
    ci.estimated_inventory_value DESC;


/* ============================================================
   SECTION 4
   REORDER AND SAFETY-STOCK RISK
   ============================================================

   Grain:
       One row per product-warehouse pair.

   Purpose:
       Identify current inventory positions that require
       operational attention.

   ============================================================ */

SELECT
    i.InventoryID,
    p.ProductID,
    p.ProductName,
    c.CategoryName,
    w.WarehouseName,
    i.QuantityOnHand,
    i.ReorderLevel,
    i.SafetyStock,

    (i.QuantityOnHand - i.ReorderLevel)
        AS units_above_below_reorder,

    (i.QuantityOnHand - i.SafetyStock)
        AS units_above_below_safety_stock,

    CASE
        WHEN i.QuantityOnHand = 0
            THEN 'Zero Stock'
        WHEN i.QuantityOnHand <= i.SafetyStock
            THEN 'At/Below Safety Stock'
        WHEN i.QuantityOnHand <= i.ReorderLevel
            THEN 'At/Below Reorder Level'
        ELSE 'Adequate'
    END AS inventory_risk_status

FROM Inventory AS i

INNER JOIN Products AS p
    ON i.ProductID = p.ProductID

INNER JOIN Categories AS c
    ON p.CategoryID = c.CategoryID

INNER JOIN Warehouses AS w
    ON i.WarehouseID = w.WarehouseID

WHERE
       i.QuantityOnHand = 0
    OR i.QuantityOnHand <= i.SafetyStock
    OR i.QuantityOnHand <= i.ReorderLevel

ORDER BY
    CASE
        WHEN i.QuantityOnHand = 0 THEN 1
        WHEN i.QuantityOnHand <= i.SafetyStock THEN 2
        ELSE 3
    END,
    i.QuantityOnHand ASC;


/* ============================================================
   SECTION 5
   ANNUAL STOCK-OUT EVENTS
   ============================================================

   Stock-out Event Definition:
       TransactionType = 'Sales Shipment'
       AND StockAfter = 0

   Grain:
       One row per year.

   ============================================================ */

WITH annual_inventory_activity AS (

    SELECT
        YEAR(TransactionDate) AS inventory_year,

        SUM(
            CASE
                WHEN TransactionType = 'Sales Shipment'
                THEN 1 ELSE 0
            END
        ) AS sales_shipment_transactions,

        SUM(
            CASE
                WHEN TransactionType = 'Sales Shipment'
                 AND StockAfter = 0
                THEN 1 ELSE 0
            END
        ) AS stockout_events

    FROM InventoryTransactions

    GROUP BY
        YEAR(TransactionDate)
)

SELECT
    inventory_year,
    sales_shipment_transactions,
    stockout_events,

    ROUND(
        stockout_events
        / NULLIF(sales_shipment_transactions, 0)
        * 100,
        2
    ) AS stockout_event_rate_pct

FROM annual_inventory_activity

ORDER BY
    inventory_year;


/* ============================================================
   SECTION 6
   STOCK-OUT EVENTS BY WAREHOUSE
   ============================================================

   Grain:
       One row per warehouse.

   Analysis Period:
       2023–2025 combined.

   ============================================================ */

SELECT
    w.WarehouseID,
    w.WarehouseName,

    SUM(
        CASE
            WHEN it.TransactionType = 'Sales Shipment'
            THEN 1 ELSE 0
        END
    ) AS sales_shipment_transactions,

    SUM(
        CASE
            WHEN it.TransactionType = 'Sales Shipment'
             AND it.StockAfter = 0
            THEN 1 ELSE 0
        END
    ) AS stockout_events,

    ROUND(
        SUM(
            CASE
                WHEN it.TransactionType = 'Sales Shipment'
                 AND it.StockAfter = 0
                THEN 1 ELSE 0
            END
        )
        /
        NULLIF(
            SUM(
                CASE
                    WHEN it.TransactionType = 'Sales Shipment'
                    THEN 1 ELSE 0
                END
            ),
            0
        )
        * 100,
        2
    ) AS stockout_event_rate_pct

FROM InventoryTransactions AS it

INNER JOIN Warehouses AS w
    ON it.WarehouseID = w.WarehouseID

GROUP BY
    w.WarehouseID,
    w.WarehouseName

ORDER BY
    stockout_event_rate_pct DESC;


/* ============================================================
   SECTION 7
   ANNUAL STOCK-OUT EVENTS BY WAREHOUSE
   ============================================================

   Grain:
       One row per year per warehouse.

   ============================================================ */

SELECT
    YEAR(it.TransactionDate) AS inventory_year,
    w.WarehouseName,

    SUM(
        CASE
            WHEN it.TransactionType = 'Sales Shipment'
            THEN 1 ELSE 0
        END
    ) AS sales_shipment_transactions,

    SUM(
        CASE
            WHEN it.TransactionType = 'Sales Shipment'
             AND it.StockAfter = 0
            THEN 1 ELSE 0
        END
    ) AS stockout_events,

    ROUND(
        SUM(
            CASE
                WHEN it.TransactionType = 'Sales Shipment'
                 AND it.StockAfter = 0
                THEN 1 ELSE 0
            END
        )
        /
        NULLIF(
            SUM(
                CASE
                    WHEN it.TransactionType = 'Sales Shipment'
                    THEN 1 ELSE 0
                END
            ),
            0
        )
        * 100,
        2
    ) AS stockout_event_rate_pct

FROM InventoryTransactions AS it

INNER JOIN Warehouses AS w
    ON it.WarehouseID = w.WarehouseID

GROUP BY
    YEAR(it.TransactionDate),
    w.WarehouseName

ORDER BY
    inventory_year,
    stockout_event_rate_pct DESC;


/* ============================================================
   SECTION 8
   PRODUCTS WITH MOST STOCK-OUT EVENTS
   ============================================================

   Grain:
       One row per product.

   ============================================================ */

SELECT
    p.ProductID,
    p.ProductName,
    c.CategoryName,

    COUNT(*) AS stockout_events,

    COUNT(DISTINCT it.WarehouseID)
        AS warehouses_affected,

    MIN(it.TransactionDate)
        AS first_stockout_date,

    MAX(it.TransactionDate)
        AS latest_stockout_date

FROM InventoryTransactions AS it

INNER JOIN Products AS p
    ON it.ProductID = p.ProductID

INNER JOIN Categories AS c
    ON p.CategoryID = c.CategoryID

WHERE it.TransactionType = 'Sales Shipment'
  AND it.StockAfter = 0

GROUP BY
    p.ProductID,
    p.ProductName,
    c.CategoryName

ORDER BY
    stockout_events DESC,
    latest_stockout_date DESC

LIMIT 20;


/* ============================================================
   SECTION 9
   CURRENT INVENTORY VS 2025 DEMAND — PRODUCT LEVEL
   ============================================================

   Grain:
       One row per product.

   Purpose:
       Compare current inventory with 2025 unit demand.

   Current Days of Supply:
       Current units /
       (2025 units sold / 365)

   Note:
       This is a demand-coverage indicator, not a forecast.

   ============================================================ */

WITH current_product_inventory AS (

    SELECT
        ProductID,
        SUM(QuantityOnHand) AS current_inventory_units
    FROM Inventory
    GROUP BY ProductID
),

product_demand_2025 AS (

    SELECT
        soi.ProductID,
        SUM(soi.QuantitySold) AS units_sold_2025

    FROM SalesOrders AS so

    INNER JOIN SalesOrderItems AS soi
        ON so.SalesOrderID = soi.SalesOrderID

    WHERE YEAR(so.OrderDate) = 2025

    GROUP BY
        soi.ProductID
)

SELECT
    p.ProductID,
    p.ProductName,
    c.CategoryName,

    COALESCE(cpi.current_inventory_units, 0)
        AS current_inventory_units,

    COALESCE(pd.units_sold_2025, 0)
        AS units_sold_2025,

    ROUND(
        COALESCE(pd.units_sold_2025, 0) / 365,
        2
    ) AS avg_daily_units_sold_2025,

    ROUND(
        COALESCE(cpi.current_inventory_units, 0)
        /
        NULLIF(
            COALESCE(pd.units_sold_2025, 0) / 365,
            0
        ),
        2
    ) AS current_days_of_supply

FROM Products AS p

INNER JOIN Categories AS c
    ON p.CategoryID = c.CategoryID

LEFT JOIN current_product_inventory AS cpi
    ON p.ProductID = cpi.ProductID

LEFT JOIN product_demand_2025 AS pd
    ON p.ProductID = pd.ProductID

ORDER BY
    current_days_of_supply DESC;


/* ============================================================
   SECTION 10
   POTENTIAL SLOW-MOVING INVENTORY CANDIDATES
   ============================================================

   Method:
       Rank products by current days of supply.

   Important:
       No arbitrary corporate slow-mover threshold is imposed.
       This output identifies candidates for management review.

   ============================================================ */

WITH current_product_inventory AS (

    SELECT
        ProductID,
        SUM(QuantityOnHand) AS current_inventory_units
    FROM Inventory
    GROUP BY ProductID
),

product_demand_2025 AS (

    SELECT
        soi.ProductID,
        SUM(soi.QuantitySold) AS units_sold_2025

    FROM SalesOrders AS so

    INNER JOIN SalesOrderItems AS soi
        ON so.SalesOrderID = soi.SalesOrderID

    WHERE YEAR(so.OrderDate) = 2025

    GROUP BY
        soi.ProductID
),

product_coverage AS (

    SELECT
        p.ProductID,
        p.ProductName,
        c.CategoryName,

        COALESCE(cpi.current_inventory_units, 0)
            AS current_inventory_units,

        COALESCE(pd.units_sold_2025, 0)
            AS units_sold_2025,

        COALESCE(cpi.current_inventory_units, 0)
        /
        NULLIF(
            COALESCE(pd.units_sold_2025, 0) / 365,
            0
        ) AS current_days_of_supply

    FROM Products AS p

    INNER JOIN Categories AS c
        ON p.CategoryID = c.CategoryID

    LEFT JOIN current_product_inventory AS cpi
        ON p.ProductID = cpi.ProductID

    LEFT JOIN product_demand_2025 AS pd
        ON p.ProductID = pd.ProductID
)

SELECT
    ProductID,
    ProductName,
    CategoryName,
    current_inventory_units,
    units_sold_2025,

    ROUND(
        current_days_of_supply,
        2
    ) AS current_days_of_supply

FROM product_coverage

ORDER BY
    current_days_of_supply DESC

LIMIT 20;


/* ============================================================
   SECTION 11
   WAREHOUSE INVENTORY VS 2025 DEMAND
   ============================================================

   Grain:
       One row per warehouse.

   Purpose:
       Evaluate whether warehouse inventory holdings appear
       proportionate to recent demand.

   ============================================================ */

WITH warehouse_inventory AS (

    SELECT
        WarehouseID,

        SUM(QuantityOnHand)
            AS current_inventory_units

    FROM Inventory

    GROUP BY
        WarehouseID
),

warehouse_demand_2025 AS (

    SELECT
        so.WarehouseID,

        SUM(soi.QuantitySold)
            AS units_sold_2025

    FROM SalesOrders AS so

    INNER JOIN SalesOrderItems AS soi
        ON so.SalesOrderID = soi.SalesOrderID

    WHERE YEAR(so.OrderDate) = 2025

    GROUP BY
        so.WarehouseID
),

inventory_total AS (

    SELECT
        SUM(current_inventory_units)
            AS company_inventory_units
    FROM warehouse_inventory
),

demand_total AS (

    SELECT
        SUM(units_sold_2025)
            AS company_units_sold_2025
    FROM warehouse_demand_2025
)

SELECT
    w.WarehouseID,
    w.WarehouseName,

    COALESCE(wi.current_inventory_units, 0)
        AS current_inventory_units,

    COALESCE(wd.units_sold_2025, 0)
        AS units_sold_2025,

    ROUND(
        COALESCE(wi.current_inventory_units, 0)
        / NULLIF(it.company_inventory_units, 0)
        * 100,
        2
    ) AS inventory_unit_share_pct,

    ROUND(
        COALESCE(wd.units_sold_2025, 0)
        / NULLIF(dt.company_units_sold_2025, 0)
        * 100,
        2
    ) AS demand_unit_share_pct,

    ROUND(
        (
            COALESCE(wi.current_inventory_units, 0)
            / NULLIF(it.company_inventory_units, 0)
            * 100
        )
        -
        (
            COALESCE(wd.units_sold_2025, 0)
            / NULLIF(dt.company_units_sold_2025, 0)
            * 100
        ),
        2
    ) AS inventory_vs_demand_share_gap_pct_points,

    ROUND(
        COALESCE(wi.current_inventory_units, 0)
        /
        NULLIF(
            COALESCE(wd.units_sold_2025, 0) / 365,
            0
        ),
        2
    ) AS current_days_of_supply

FROM Warehouses AS w

LEFT JOIN warehouse_inventory AS wi
    ON w.WarehouseID = wi.WarehouseID

LEFT JOIN warehouse_demand_2025 AS wd
    ON w.WarehouseID = wd.WarehouseID

CROSS JOIN inventory_total AS it

CROSS JOIN demand_total AS dt

ORDER BY
    current_days_of_supply DESC;


/* ============================================================
   SECTION 12
   2025 OPENING AND CLOSING INVENTORY BY PRODUCT-WAREHOUSE
   ============================================================

   Grain:
       One row per product-warehouse pair.

   Method:
       Opening Inventory Units:
           StockBefore of the first 2025 inventory transaction.

       Closing Inventory Units:
           StockAfter of the last 2025 inventory transaction.

       Average Inventory Units:
           (Opening + Closing) / 2

   ============================================================ */

WITH ranked_2025_transactions AS (

    SELECT
        it.ProductID,
        it.WarehouseID,
        it.TransactionDate,
        it.InventoryTransactionID,
        it.StockBefore,
        it.StockAfter,

        ROW_NUMBER() OVER (
            PARTITION BY
                it.ProductID,
                it.WarehouseID
            ORDER BY
                it.TransactionDate,
                it.InventoryTransactionID
        ) AS rn_first,

        ROW_NUMBER() OVER (
            PARTITION BY
                it.ProductID,
                it.WarehouseID
            ORDER BY
                it.TransactionDate DESC,
                it.InventoryTransactionID DESC
        ) AS rn_last

    FROM InventoryTransactions AS it

    WHERE YEAR(it.TransactionDate) = 2025
),

pair_inventory AS (

    SELECT
        ProductID,
        WarehouseID,

        MAX(
            CASE
                WHEN rn_first = 1
                THEN StockBefore
            END
        ) AS opening_inventory_units,

        MAX(
            CASE
                WHEN rn_last = 1
                THEN StockAfter
            END
        ) AS closing_inventory_units

    FROM ranked_2025_transactions

    GROUP BY
        ProductID,
        WarehouseID
)

SELECT
    pi.ProductID,
    p.ProductName,
    pi.WarehouseID,
    w.WarehouseName,
    pi.opening_inventory_units,
    pi.closing_inventory_units,

    ROUND(
        (
            pi.opening_inventory_units
            + pi.closing_inventory_units
        ) / 2,
        2
    ) AS average_inventory_units_2025

FROM pair_inventory AS pi

INNER JOIN Products AS p
    ON pi.ProductID = p.ProductID

INNER JOIN Warehouses AS w
    ON pi.WarehouseID = w.WarehouseID

ORDER BY
    pi.ProductID,
    pi.WarehouseID;


/* ============================================================
   SECTION 13
   2025 ESTIMATED COMPANY INVENTORY TURNOVER
   ============================================================

   Cost-based metric restricted to 2025.

   Estimated COGS:
       2025 QuantitySold * current StandardCost.

   Average Inventory Value:
       Average 2025 opening/closing inventory units
       * current StandardCost.

   ============================================================ */

WITH ranked_2025_transactions AS (

    SELECT
        it.ProductID,
        it.WarehouseID,
        it.TransactionDate,
        it.InventoryTransactionID,
        it.StockBefore,
        it.StockAfter,

        ROW_NUMBER() OVER (
            PARTITION BY
                it.ProductID,
                it.WarehouseID
            ORDER BY
                it.TransactionDate,
                it.InventoryTransactionID
        ) AS rn_first,

        ROW_NUMBER() OVER (
            PARTITION BY
                it.ProductID,
                it.WarehouseID
            ORDER BY
                it.TransactionDate DESC,
                it.InventoryTransactionID DESC
        ) AS rn_last

    FROM InventoryTransactions AS it

    WHERE YEAR(it.TransactionDate) = 2025
),

pair_inventory AS (

    SELECT
        ProductID,
        WarehouseID,

        MAX(
            CASE WHEN rn_first = 1
                 THEN StockBefore END
        ) AS opening_inventory_units,

        MAX(
            CASE WHEN rn_last = 1
                 THEN StockAfter END
        ) AS closing_inventory_units

    FROM ranked_2025_transactions

    GROUP BY
        ProductID,
        WarehouseID
),

average_inventory AS (

    SELECT
        SUM(
            (
                pi.opening_inventory_units
                + pi.closing_inventory_units
            ) / 2
            * p.StandardCost
        ) AS estimated_average_inventory_value_2025

    FROM pair_inventory AS pi

    INNER JOIN Products AS p
        ON pi.ProductID = p.ProductID
),

estimated_cogs AS (

    SELECT
        SUM(
            soi.QuantitySold * p.StandardCost
        ) AS estimated_cogs_2025

    FROM SalesOrders AS so

    INNER JOIN SalesOrderItems AS soi
        ON so.SalesOrderID = soi.SalesOrderID

    INNER JOIN Products AS p
        ON soi.ProductID = p.ProductID

    WHERE YEAR(so.OrderDate) = 2025
)

SELECT
    ROUND(
        ec.estimated_cogs_2025,
        2
    ) AS estimated_cogs_2025,

    ROUND(
        ai.estimated_average_inventory_value_2025,
        2
    ) AS estimated_average_inventory_value_2025,

    ROUND(
        ec.estimated_cogs_2025
        / NULLIF(
            ai.estimated_average_inventory_value_2025,
            0
        ),
        2
    ) AS estimated_inventory_turnover_2025,

    ROUND(
        365
        /
        NULLIF(
            ec.estimated_cogs_2025
            / NULLIF(
                ai.estimated_average_inventory_value_2025,
                0
            ),
            0
        ),
        2
    ) AS estimated_days_of_inventory_2025

FROM estimated_cogs AS ec

CROSS JOIN average_inventory AS ai;


/* ============================================================
   SECTION 14
   2025 ESTIMATED INVENTORY TURNOVER BY CATEGORY
   ============================================================

   Grain:
       One row per category.

   ============================================================ */

WITH ranked_2025_transactions AS (

    SELECT
        it.ProductID,
        it.WarehouseID,
        it.TransactionDate,
        it.InventoryTransactionID,
        it.StockBefore,
        it.StockAfter,

        ROW_NUMBER() OVER (
            PARTITION BY
                it.ProductID,
                it.WarehouseID
            ORDER BY
                it.TransactionDate,
                it.InventoryTransactionID
        ) AS rn_first,

        ROW_NUMBER() OVER (
            PARTITION BY
                it.ProductID,
                it.WarehouseID
            ORDER BY
                it.TransactionDate DESC,
                it.InventoryTransactionID DESC
        ) AS rn_last

    FROM InventoryTransactions AS it

    WHERE YEAR(it.TransactionDate) = 2025
),

pair_inventory AS (

    SELECT
        ProductID,
        WarehouseID,

        MAX(
            CASE WHEN rn_first = 1
                 THEN StockBefore END
        ) AS opening_inventory_units,

        MAX(
            CASE WHEN rn_last = 1
                 THEN StockAfter END
        ) AS closing_inventory_units

    FROM ranked_2025_transactions

    GROUP BY
        ProductID,
        WarehouseID
),

category_average_inventory AS (

    SELECT
        c.CategoryID,
        c.CategoryName,

        SUM(
            (
                pi.opening_inventory_units
                + pi.closing_inventory_units
            ) / 2
            * p.StandardCost
        ) AS estimated_average_inventory_value_2025

    FROM pair_inventory AS pi

    INNER JOIN Products AS p
        ON pi.ProductID = p.ProductID

    INNER JOIN Categories AS c
        ON p.CategoryID = c.CategoryID

    GROUP BY
        c.CategoryID,
        c.CategoryName
),

category_cogs AS (

    SELECT
        c.CategoryID,
        c.CategoryName,

        SUM(
            soi.QuantitySold * p.StandardCost
        ) AS estimated_cogs_2025

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
    cc.CategoryID,
    cc.CategoryName,

    ROUND(
        cc.estimated_cogs_2025,
        2
    ) AS estimated_cogs_2025,

    ROUND(
        cai.estimated_average_inventory_value_2025,
        2
    ) AS estimated_average_inventory_value_2025,

    ROUND(
        cc.estimated_cogs_2025
        / NULLIF(
            cai.estimated_average_inventory_value_2025,
            0
        ),
        2
    ) AS estimated_inventory_turnover_2025,

    ROUND(
        365
        /
        NULLIF(
            cc.estimated_cogs_2025
            / NULLIF(
                cai.estimated_average_inventory_value_2025,
                0
            ),
            0
        ),
        2
    ) AS estimated_days_of_inventory_2025

FROM category_cogs AS cc

INNER JOIN category_average_inventory AS cai
    ON cc.CategoryID = cai.CategoryID

ORDER BY
    estimated_inventory_turnover_2025 DESC;


/* ============================================================
   SECTION 15
   CURRENT INVENTORY VALUE RECONCILIATION
   ============================================================

   Purpose:
       Confirm warehouse-level current inventory value
       reconciles to the company current inventory value.

   Expected Result:
       reconciliation_difference = 0.00

   ============================================================ */

WITH warehouse_inventory AS (

    SELECT
        i.WarehouseID,

        SUM(
            i.QuantityOnHand * p.StandardCost
        ) AS warehouse_inventory_value

    FROM Inventory AS i

    INNER JOIN Products AS p
        ON i.ProductID = p.ProductID

    GROUP BY
        i.WarehouseID
),

company_inventory AS (

    SELECT
        SUM(
            i.QuantityOnHand * p.StandardCost
        ) AS company_inventory_value

    FROM Inventory AS i

    INNER JOIN Products AS p
        ON i.ProductID = p.ProductID
)

SELECT
    ROUND(
        SUM(wi.warehouse_inventory_value),
        2
    ) AS sum_of_warehouse_inventory_value,

    ROUND(
        ci.company_inventory_value,
        2
    ) AS company_inventory_value,

    ROUND(
        SUM(wi.warehouse_inventory_value)
        - ci.company_inventory_value,
        2
    ) AS reconciliation_difference

FROM warehouse_inventory AS wi

CROSS JOIN company_inventory AS ci

GROUP BY
    ci.company_inventory_value;


/* ============================================================
   SECTION 16
   CURRENT INVENTORY UNIT RECONCILIATION
   ============================================================

   Expected Result:
       reconciliation_difference = 0

   ============================================================ */

WITH warehouse_inventory AS (

    SELECT
        WarehouseID,
        SUM(QuantityOnHand) AS warehouse_inventory_units

    FROM Inventory

    GROUP BY
        WarehouseID
),

company_inventory AS (

    SELECT
        SUM(QuantityOnHand) AS company_inventory_units
    FROM Inventory
)

SELECT
    SUM(wi.warehouse_inventory_units)
        AS sum_of_warehouse_inventory_units,

    ci.company_inventory_units
        AS company_inventory_units,

    SUM(wi.warehouse_inventory_units)
    - ci.company_inventory_units
        AS reconciliation_difference

FROM warehouse_inventory AS wi

CROSS JOIN company_inventory AS ci

GROUP BY
    ci.company_inventory_units;


/* ============================================================
   SECTION 17
   STOCK-OUT EVENT RECONCILIATION
   ============================================================

   Purpose:
       Confirm the annual stock-out event total reconciles
       to the company-wide stock-out event count.

   Expected Result:
       reconciliation_difference = 0

   ============================================================ */

WITH annual_stockouts AS (

    SELECT
        YEAR(TransactionDate) AS inventory_year,
        COUNT(*) AS stockout_events

    FROM InventoryTransactions

    WHERE TransactionType = 'Sales Shipment'
      AND StockAfter = 0

    GROUP BY
        YEAR(TransactionDate)
),

company_stockouts AS (

    SELECT
        COUNT(*) AS stockout_events

    FROM InventoryTransactions

    WHERE TransactionType = 'Sales Shipment'
      AND StockAfter = 0
)

SELECT
    SUM(a.stockout_events)
        AS sum_of_annual_stockout_events,

    c.stockout_events
        AS company_stockout_events,

    SUM(a.stockout_events)
    - c.stockout_events
        AS reconciliation_difference

FROM annual_stockouts AS a

CROSS JOIN company_stockouts AS c

GROUP BY
    c.stockout_events;


/* ============================================================
   END OF PHASE 6D.3 — VERSION 1.0
   ============================================================ */
