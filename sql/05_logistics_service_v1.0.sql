/* ============================================================
   NOVAMART CONSUMER GOODS LIMITED
   SUPPLY CHAIN INTELLIGENCE PLATFORM

   PHASE 6D.5 — LOGISTICS & SERVICE PERFORMANCE

   Module:
       05_logistics_service.sql

   Version:
       1.0

   Database:
       novamart_supply_chain

   Platform:
       MySQL 8.0+

   Analysis Period:
       2023–2025

   Purpose:
       Evaluate customer delivery reliability, warehouse service
       performance, delay concentration, transport cost trends,
       and the operational drivers of logistics cost.

   Primary Business Questions:
       1. What is NovaMart's on-time delivery rate?
       2. How has delivery performance changed over time?
       3. Which warehouses deliver most efficiently?
       4. Where are delivery delays concentrated?
       5. Which customer segments experience the strongest or
          weakest service performance?
       6. How has transport cost changed over time?
       7. Which warehouses generate the highest logistics cost?
       8. How strongly is transport cost associated with distance?
       9. How strongly is transport cost associated with shipment weight?
       10. Which shipments are operationally expensive relative
           to distance or shipment weight?

   Core KPI Definitions:
       Delivered Shipments
           = COUNT(Shipments.ShipmentID)

       On-Time Delivery
           = DeliveryDate <= RequiredDeliveryDate

       On-Time Delivery Rate
           = On-Time Delivered Shipments / Delivered Shipments * 100

       Delivery Delay Days
           = GREATEST(DATEDIFF(DeliveryDate, RequiredDeliveryDate), 0)

       Transport Cost
           = SUM(Shipments.TransportCost)

       Average Transport Cost per Shipment
           = Transport Cost / Delivered Shipments

       Transport Cost per KM
           = TransportCost / DeliveryDistanceKM

       Shipment Weight
           = SUM(SalesOrderItems.QuantitySold * Products.ProductWeight)
             at SalesOrderID grain

       Transport Cost per KG
           = TransportCost / ShipmentWeightKG

   Methodological Governance:
       - Shipments is the logistics cost/service fact table.
       - One shipment exists per sales order in the approved dataset.
       - Delivery performance is evaluated against
         SalesOrders.RequiredDeliveryDate.
       - Shipment weight is aggregated from SalesOrderItems before
         joining to Shipments.
       - Transport cost is never duplicated across sales-order items.
       - Distance and weight are analysed as operational drivers,
         not assumed causal without evidence.
       - Correlation results are descriptive, not causal proof.
       - Payments and PurchaseOrders are excluded from logistics
         cost calculations.

   Analytical Grains:
       Shipment grain
       Warehouse grain
       Year grain
       Month grain
       Customer-type grain
       Shipment-level cost-driver grain

   Source Tables:
       Shipments
       SalesOrders
       SalesOrderItems
       Products
       Warehouses
       Customers

   ============================================================ */

USE novamart_supply_chain;


/* ============================================================
   SECTION 1
   LOGISTICS ANALYTICAL BASE
   ============================================================ */

WITH shipment_weight AS (

    SELECT
        soi.SalesOrderID,

        SUM(
            soi.QuantitySold * p.ProductWeight
        ) AS shipment_weight_kg

    FROM SalesOrderItems AS soi

    INNER JOIN Products AS p
        ON soi.ProductID = p.ProductID

    GROUP BY
        soi.SalesOrderID
)

SELECT
    sh.ShipmentID,
    sh.SalesOrderID,
    sh.WarehouseID,
    w.WarehouseName,
    so.CustomerID,
    cu.CustomerType,
    so.OrderDate,
    so.RequiredDeliveryDate,
    sh.ShipmentDate,
    sh.DeliveryDate,
    sh.DeliveryStatus,
    sh.TransportCost,
    sh.DeliveryDistanceKM,
    sw.shipment_weight_kg,

    CASE
        WHEN sh.DeliveryDate <= so.RequiredDeliveryDate
        THEN 1 ELSE 0
    END AS on_time_delivery_flag,

    GREATEST(
        DATEDIFF(
            sh.DeliveryDate,
            so.RequiredDeliveryDate
        ),
        0
    ) AS delivery_delay_days

FROM Shipments AS sh

INNER JOIN SalesOrders AS so
    ON sh.SalesOrderID = so.SalesOrderID

INNER JOIN Warehouses AS w
    ON sh.WarehouseID = w.WarehouseID

INNER JOIN Customers AS cu
    ON so.CustomerID = cu.CustomerID

INNER JOIN shipment_weight AS sw
    ON sh.SalesOrderID = sw.SalesOrderID;


/* ============================================================
   SECTION 2
   COMPANY DELIVERY PERFORMANCE SUMMARY
   ============================================================ */

SELECT
    COUNT(sh.ShipmentID) AS delivered_shipments,

    SUM(
        CASE
            WHEN sh.DeliveryDate <= so.RequiredDeliveryDate
            THEN 1 ELSE 0
        END
    ) AS on_time_shipments,

    SUM(
        CASE
            WHEN sh.DeliveryDate > so.RequiredDeliveryDate
            THEN 1 ELSE 0
        END
    ) AS late_shipments,

    ROUND(
        SUM(
            CASE
                WHEN sh.DeliveryDate <= so.RequiredDeliveryDate
                THEN 1 ELSE 0
            END
        )
        / NULLIF(COUNT(sh.ShipmentID),0)
        * 100,
        2
    ) AS on_time_delivery_rate_pct,

    ROUND(
        AVG(
            GREATEST(
                DATEDIFF(
                    sh.DeliveryDate,
                    so.RequiredDeliveryDate
                ),
                0
            )
        ),
        2
    ) AS avg_delay_days_all_shipments,

    ROUND(
        AVG(
            CASE
                WHEN sh.DeliveryDate > so.RequiredDeliveryDate
                THEN DATEDIFF(
                    sh.DeliveryDate,
                    so.RequiredDeliveryDate
                )
            END
        ),
        2
    ) AS avg_delay_days_late_shipments

FROM Shipments AS sh

INNER JOIN SalesOrders AS so
    ON sh.SalesOrderID = so.SalesOrderID;


/* ============================================================
   SECTION 3
   ANNUAL DELIVERY PERFORMANCE
   ============================================================ */

SELECT
    YEAR(so.OrderDate) AS delivery_year,

    COUNT(sh.ShipmentID)
        AS delivered_shipments,

    SUM(
        CASE
            WHEN sh.DeliveryDate <= so.RequiredDeliveryDate
            THEN 1 ELSE 0
        END
    ) AS on_time_shipments,

    SUM(
        CASE
            WHEN sh.DeliveryDate > so.RequiredDeliveryDate
            THEN 1 ELSE 0
        END
    ) AS late_shipments,

    ROUND(
        SUM(
            CASE
                WHEN sh.DeliveryDate <= so.RequiredDeliveryDate
                THEN 1 ELSE 0
            END
        )
        / NULLIF(COUNT(sh.ShipmentID),0)
        * 100,
        2
    ) AS on_time_delivery_rate_pct,

    ROUND(
        AVG(
            CASE
                WHEN sh.DeliveryDate > so.RequiredDeliveryDate
                THEN DATEDIFF(
                    sh.DeliveryDate,
                    so.RequiredDeliveryDate
                )
            END
        ),
        2
    ) AS avg_delay_days_late_shipments

FROM Shipments AS sh

INNER JOIN SalesOrders AS so
    ON sh.SalesOrderID = so.SalesOrderID

GROUP BY
    YEAR(so.OrderDate)

ORDER BY
    delivery_year;


/* ============================================================
   SECTION 4
   MONTHLY DELIVERY PERFORMANCE
   ============================================================ */

SELECT
    YEAR(so.OrderDate) AS delivery_year,
    MONTH(so.OrderDate) AS delivery_month,

    COUNT(sh.ShipmentID)
        AS delivered_shipments,

    ROUND(
        SUM(
            CASE
                WHEN sh.DeliveryDate <= so.RequiredDeliveryDate
                THEN 1 ELSE 0
            END
        )
        / NULLIF(COUNT(sh.ShipmentID),0)
        * 100,
        2
    ) AS on_time_delivery_rate_pct,

    SUM(
        CASE
            WHEN sh.DeliveryDate > so.RequiredDeliveryDate
            THEN 1 ELSE 0
        END
    ) AS late_shipments

FROM Shipments AS sh

INNER JOIN SalesOrders AS so
    ON sh.SalesOrderID = so.SalesOrderID

GROUP BY
    YEAR(so.OrderDate),
    MONTH(so.OrderDate)

ORDER BY
    delivery_year,
    delivery_month;


/* ============================================================
   SECTION 5
   WAREHOUSE DELIVERY PERFORMANCE
   ============================================================ */

SELECT
    w.WarehouseID,
    w.WarehouseName,

    COUNT(sh.ShipmentID)
        AS delivered_shipments,

    SUM(
        CASE
            WHEN sh.DeliveryDate <= so.RequiredDeliveryDate
            THEN 1 ELSE 0
        END
    ) AS on_time_shipments,

    SUM(
        CASE
            WHEN sh.DeliveryDate > so.RequiredDeliveryDate
            THEN 1 ELSE 0
        END
    ) AS late_shipments,

    ROUND(
        SUM(
            CASE
                WHEN sh.DeliveryDate <= so.RequiredDeliveryDate
                THEN 1 ELSE 0
            END
        )
        / NULLIF(COUNT(sh.ShipmentID),0)
        * 100,
        2
    ) AS on_time_delivery_rate_pct,

    ROUND(
        AVG(
            CASE
                WHEN sh.DeliveryDate > so.RequiredDeliveryDate
                THEN DATEDIFF(
                    sh.DeliveryDate,
                    so.RequiredDeliveryDate
                )
            END
        ),
        2
    ) AS avg_delay_days_late_shipments

FROM Shipments AS sh

INNER JOIN SalesOrders AS so
    ON sh.SalesOrderID = so.SalesOrderID

INNER JOIN Warehouses AS w
    ON sh.WarehouseID = w.WarehouseID

GROUP BY
    w.WarehouseID,
    w.WarehouseName

ORDER BY
    on_time_delivery_rate_pct DESC;


/* ============================================================
   SECTION 6
   ANNUAL WAREHOUSE DELIVERY PERFORMANCE
   ============================================================ */

SELECT
    YEAR(so.OrderDate) AS delivery_year,
    w.WarehouseName,

    COUNT(sh.ShipmentID)
        AS delivered_shipments,

    ROUND(
        SUM(
            CASE
                WHEN sh.DeliveryDate <= so.RequiredDeliveryDate
                THEN 1 ELSE 0
            END
        )
        / NULLIF(COUNT(sh.ShipmentID),0)
        * 100,
        2
    ) AS on_time_delivery_rate_pct,

    ROUND(
        AVG(
            CASE
                WHEN sh.DeliveryDate > so.RequiredDeliveryDate
                THEN DATEDIFF(
                    sh.DeliveryDate,
                    so.RequiredDeliveryDate
                )
            END
        ),
        2
    ) AS avg_delay_days_late_shipments

FROM Shipments AS sh

INNER JOIN SalesOrders AS so
    ON sh.SalesOrderID = so.SalesOrderID

INNER JOIN Warehouses AS w
    ON sh.WarehouseID = w.WarehouseID

GROUP BY
    YEAR(so.OrderDate),
    w.WarehouseName

ORDER BY
    delivery_year,
    on_time_delivery_rate_pct DESC;


/* ============================================================
   SECTION 7
   CUSTOMER TYPE SERVICE PERFORMANCE
   ============================================================ */

SELECT
    cu.CustomerType,

    COUNT(sh.ShipmentID)
        AS delivered_shipments,

    ROUND(
        SUM(
            CASE
                WHEN sh.DeliveryDate <= so.RequiredDeliveryDate
                THEN 1 ELSE 0
            END
        )
        / NULLIF(COUNT(sh.ShipmentID),0)
        * 100,
        2
    ) AS on_time_delivery_rate_pct,

    SUM(
        CASE
            WHEN sh.DeliveryDate > so.RequiredDeliveryDate
            THEN 1 ELSE 0
        END
    ) AS late_shipments,

    ROUND(
        AVG(
            CASE
                WHEN sh.DeliveryDate > so.RequiredDeliveryDate
                THEN DATEDIFF(
                    sh.DeliveryDate,
                    so.RequiredDeliveryDate
                )
            END
        ),
        2
    ) AS avg_delay_days_late_shipments

FROM Shipments AS sh

INNER JOIN SalesOrders AS so
    ON sh.SalesOrderID = so.SalesOrderID

INNER JOIN Customers AS cu
    ON so.CustomerID = cu.CustomerID

GROUP BY
    cu.CustomerType

ORDER BY
    on_time_delivery_rate_pct DESC;


/* ============================================================
   SECTION 8
   DELAY SEVERITY DISTRIBUTION
   ============================================================ */

WITH delay_base AS (

    SELECT
        CASE
            WHEN sh.DeliveryDate <= so.RequiredDeliveryDate
                THEN 'On Time'
            WHEN DATEDIFF(
                sh.DeliveryDate,
                so.RequiredDeliveryDate
            ) BETWEEN 1 AND 2
                THEN '1-2 Days Late'
            WHEN DATEDIFF(
                sh.DeliveryDate,
                so.RequiredDeliveryDate
            ) BETWEEN 3 AND 5
                THEN '3-5 Days Late'
            ELSE '6+ Days Late'
        END AS delay_band

    FROM Shipments AS sh

    INNER JOIN SalesOrders AS so
        ON sh.SalesOrderID = so.SalesOrderID
)

SELECT
    delay_band,
    COUNT(*) AS shipments,

    ROUND(
        COUNT(*)
        / SUM(COUNT(*)) OVER ()
        * 100,
        2
    ) AS shipment_share_pct

FROM delay_base

GROUP BY
    delay_band

ORDER BY
    CASE delay_band
        WHEN 'On Time' THEN 1
        WHEN '1-2 Days Late' THEN 2
        WHEN '3-5 Days Late' THEN 3
        ELSE 4
    END;


/* ============================================================
   SECTION 9
   COMPANY TRANSPORT COST SUMMARY
   ============================================================ */

SELECT
    ROUND(
        SUM(sh.TransportCost),
        2
    ) AS total_transport_cost,

    COUNT(sh.ShipmentID)
        AS shipments,

    ROUND(
        AVG(sh.TransportCost),
        2
    ) AS average_transport_cost_per_shipment,

    ROUND(
        SUM(sh.TransportCost)
        / NULLIF(
            SUM(sh.DeliveryDistanceKM),
            0
        ),
        2
    ) AS transport_cost_per_km,

    ROUND(
        AVG(sh.DeliveryDistanceKM),
        2
    ) AS average_delivery_distance_km

FROM Shipments AS sh;


/* ============================================================
   SECTION 10
   ANNUAL TRANSPORT COST PERFORMANCE
   ============================================================ */

SELECT
    YEAR(so.OrderDate) AS logistics_year,

    ROUND(
        SUM(sh.TransportCost),
        2
    ) AS transport_cost,

    COUNT(sh.ShipmentID)
        AS shipments,

    ROUND(
        AVG(sh.TransportCost),
        2
    ) AS avg_transport_cost_per_shipment,

    ROUND(
        AVG(sh.DeliveryDistanceKM),
        2
    ) AS avg_delivery_distance_km,

    ROUND(
        SUM(sh.TransportCost)
        / NULLIF(
            SUM(sh.DeliveryDistanceKM),
            0
        ),
        2
    ) AS transport_cost_per_km

FROM Shipments AS sh

INNER JOIN SalesOrders AS so
    ON sh.SalesOrderID = so.SalesOrderID

GROUP BY
    YEAR(so.OrderDate)

ORDER BY
    logistics_year;


/* ============================================================
   SECTION 11
   WAREHOUSE TRANSPORT COST PERFORMANCE
   ============================================================ */

WITH warehouse_transport AS (

    SELECT
        w.WarehouseID,
        w.WarehouseName,

        SUM(sh.TransportCost)
            AS transport_cost,

        COUNT(sh.ShipmentID)
            AS shipments,

        AVG(sh.TransportCost)
            AS avg_transport_cost_per_shipment,

        AVG(sh.DeliveryDistanceKM)
            AS avg_delivery_distance_km

    FROM Shipments AS sh

    INNER JOIN Warehouses AS w
        ON sh.WarehouseID = w.WarehouseID

    GROUP BY
        w.WarehouseID,
        w.WarehouseName
),

company_transport AS (

    SELECT
        SUM(transport_cost)
            AS company_transport_cost

    FROM warehouse_transport
)

SELECT
    wt.WarehouseID,
    wt.WarehouseName,

    ROUND(
        wt.transport_cost,
        2
    ) AS transport_cost,

    wt.shipments,

    ROUND(
        wt.avg_transport_cost_per_shipment,
        2
    ) AS avg_transport_cost_per_shipment,

    ROUND(
        wt.avg_delivery_distance_km,
        2
    ) AS avg_delivery_distance_km,

    ROUND(
        wt.transport_cost
        / NULLIF(ct.company_transport_cost,0)
        * 100,
        2
    ) AS transport_cost_share_pct

FROM warehouse_transport AS wt

CROSS JOIN company_transport AS ct

ORDER BY
    wt.transport_cost DESC;


/* ============================================================
   SECTION 12
   SHIPMENT WEIGHT & TRANSPORT COST BASE
   ============================================================ */

WITH shipment_weight AS (

    SELECT
        soi.SalesOrderID,

        SUM(
            soi.QuantitySold * p.ProductWeight
        ) AS shipment_weight_kg

    FROM SalesOrderItems AS soi

    INNER JOIN Products AS p
        ON soi.ProductID = p.ProductID

    GROUP BY
        soi.SalesOrderID
)

SELECT
    sh.ShipmentID,
    sh.SalesOrderID,
    sh.WarehouseID,
    sh.TransportCost,
    sh.DeliveryDistanceKM,
    sw.shipment_weight_kg,

    ROUND(
        sh.TransportCost
        / NULLIF(sh.DeliveryDistanceKM,0),
        2
    ) AS transport_cost_per_km,

    ROUND(
        sh.TransportCost
        / NULLIF(sw.shipment_weight_kg,0),
        2
    ) AS transport_cost_per_kg

FROM Shipments AS sh

INNER JOIN shipment_weight AS sw
    ON sh.SalesOrderID = sw.SalesOrderID;


/* ============================================================
   SECTION 13
   TRANSPORT COST CORRELATION WITH DISTANCE
   ============================================================ */

WITH base AS (

    SELECT
        CAST(sh.TransportCost AS DECIMAL(18,6)) AS x,
        CAST(sh.DeliveryDistanceKM AS DECIMAL(18,6)) AS y

    FROM Shipments AS sh
),

stats AS (

    SELECT
        COUNT(*) AS n,
        SUM(x) AS sum_x,
        SUM(y) AS sum_y,
        SUM(x * y) AS sum_xy,
        SUM(x * x) AS sum_x2,
        SUM(y * y) AS sum_y2

    FROM base
)

SELECT
    ROUND(
        (
            n * sum_xy - sum_x * sum_y
        )
        /
        NULLIF(
            SQRT(
                (n * sum_x2 - sum_x * sum_x)
                *
                (n * sum_y2 - sum_y * sum_y)
            ),
            0
        ),
        4
    ) AS transport_cost_distance_correlation

FROM stats;


/* ============================================================
   SECTION 14
   TRANSPORT COST CORRELATION WITH SHIPMENT WEIGHT
   ============================================================ */

WITH shipment_weight AS (

    SELECT
        soi.SalesOrderID,

        SUM(
            soi.QuantitySold * p.ProductWeight
        ) AS shipment_weight_kg

    FROM SalesOrderItems AS soi

    INNER JOIN Products AS p
        ON soi.ProductID = p.ProductID

    GROUP BY
        soi.SalesOrderID
),

base AS (

    SELECT
        CAST(sh.TransportCost AS DECIMAL(18,6)) AS x,
        CAST(sw.shipment_weight_kg AS DECIMAL(18,6)) AS y

    FROM Shipments AS sh

    INNER JOIN shipment_weight AS sw
        ON sh.SalesOrderID = sw.SalesOrderID
),

stats AS (

    SELECT
        COUNT(*) AS n,
        SUM(x) AS sum_x,
        SUM(y) AS sum_y,
        SUM(x * y) AS sum_xy,
        SUM(x * x) AS sum_x2,
        SUM(y * y) AS sum_y2

    FROM base
)

SELECT
    ROUND(
        (
            n * sum_xy - sum_x * sum_y
        )
        /
        NULLIF(
            SQRT(
                (n * sum_x2 - sum_x * sum_x)
                *
                (n * sum_y2 - sum_y * sum_y)
            ),
            0
        ),
        4
    ) AS transport_cost_weight_correlation

FROM stats;


/* ============================================================
   SECTION 15
   HIGHEST-COST SHIPMENTS
   ============================================================ */

WITH shipment_weight AS (

    SELECT
        soi.SalesOrderID,

        SUM(
            soi.QuantitySold * p.ProductWeight
        ) AS shipment_weight_kg

    FROM SalesOrderItems AS soi

    INNER JOIN Products AS p
        ON soi.ProductID = p.ProductID

    GROUP BY
        soi.SalesOrderID
)

SELECT
    sh.ShipmentID,
    sh.SalesOrderID,
    w.WarehouseName,
    sh.TransportCost,
    sh.DeliveryDistanceKM,
    sw.shipment_weight_kg,

    ROUND(
        sh.TransportCost
        / NULLIF(sh.DeliveryDistanceKM,0),
        2
    ) AS transport_cost_per_km,

    ROUND(
        sh.TransportCost
        / NULLIF(sw.shipment_weight_kg,0),
        2
    ) AS transport_cost_per_kg

FROM Shipments AS sh

INNER JOIN Warehouses AS w
    ON sh.WarehouseID = w.WarehouseID

INNER JOIN shipment_weight AS sw
    ON sh.SalesOrderID = sw.SalesOrderID

ORDER BY
    sh.TransportCost DESC

LIMIT 20;


/* ============================================================
   SECTION 16
   LATE SHIPMENT CONCENTRATION BY WAREHOUSE
   ============================================================ */

WITH warehouse_late AS (

    SELECT
        w.WarehouseID,
        w.WarehouseName,

        SUM(
            CASE
                WHEN sh.DeliveryDate > so.RequiredDeliveryDate
                THEN 1 ELSE 0
            END
        ) AS late_shipments

    FROM Shipments AS sh

    INNER JOIN SalesOrders AS so
        ON sh.SalesOrderID = so.SalesOrderID

    INNER JOIN Warehouses AS w
        ON sh.WarehouseID = w.WarehouseID

    GROUP BY
        w.WarehouseID,
        w.WarehouseName
),

company_late AS (

    SELECT
        SUM(late_shipments)
            AS company_late_shipments

    FROM warehouse_late
)

SELECT
    wl.WarehouseID,
    wl.WarehouseName,
    wl.late_shipments,

    ROUND(
        wl.late_shipments
        / NULLIF(cl.company_late_shipments,0)
        * 100,
        2
    ) AS late_shipment_share_pct

FROM warehouse_late AS wl

CROSS JOIN company_late AS cl

ORDER BY
    wl.late_shipments DESC;


/* ============================================================
   SECTION 17
   DELIVERY PERFORMANCE RECONCILIATION
   ============================================================ */

SELECT
    COUNT(sh.ShipmentID)
        AS total_shipments,

    SUM(
        CASE
            WHEN sh.DeliveryDate <= so.RequiredDeliveryDate
            THEN 1 ELSE 0
        END
    )
    +
    SUM(
        CASE
            WHEN sh.DeliveryDate > so.RequiredDeliveryDate
            THEN 1 ELSE 0
        END
    ) AS classified_shipments,

    COUNT(sh.ShipmentID)
    -
    (
        SUM(
            CASE
                WHEN sh.DeliveryDate <= so.RequiredDeliveryDate
                THEN 1 ELSE 0
            END
        )
        +
        SUM(
            CASE
                WHEN sh.DeliveryDate > so.RequiredDeliveryDate
                THEN 1 ELSE 0
            END
        )
    ) AS reconciliation_difference

FROM Shipments AS sh

INNER JOIN SalesOrders AS so
    ON sh.SalesOrderID = so.SalesOrderID;


/* ============================================================
   SECTION 18
   TRANSPORT COST RECONCILIATION
   ============================================================ */

WITH warehouse_cost AS (

    SELECT
        WarehouseID,
        SUM(TransportCost) AS warehouse_transport_cost

    FROM Shipments

    GROUP BY
        WarehouseID
),

company_cost AS (

    SELECT
        SUM(TransportCost) AS company_transport_cost

    FROM Shipments
)

SELECT
    ROUND(
        SUM(wc.warehouse_transport_cost),
        2
    ) AS sum_of_warehouse_transport_cost,

    ROUND(
        cc.company_transport_cost,
        2
    ) AS company_transport_cost,

    ROUND(
        SUM(wc.warehouse_transport_cost)
        - cc.company_transport_cost,
        2
    ) AS reconciliation_difference

FROM warehouse_cost AS wc

CROSS JOIN company_cost AS cc

GROUP BY
    cc.company_transport_cost;


/* ============================================================
   SECTION 19
   SHIPMENT COUNT RECONCILIATION
   ============================================================ */

SELECT
    (SELECT COUNT(*) FROM Shipments)
        AS shipment_rows,

    (SELECT COUNT(*) FROM SalesOrders)
        AS sales_order_rows,

    (SELECT COUNT(DISTINCT SalesOrderID) FROM Shipments)
        AS distinct_shipment_sales_orders,

    (
        SELECT COUNT(*)
        FROM SalesOrders AS so
        LEFT JOIN Shipments AS sh
            ON so.SalesOrderID = sh.SalesOrderID
        WHERE sh.ShipmentID IS NULL
    ) AS sales_orders_without_shipment,

    (
        SELECT COUNT(*)
        FROM Shipments AS sh
        LEFT JOIN SalesOrders AS so
            ON sh.SalesOrderID = so.SalesOrderID
        WHERE so.SalesOrderID IS NULL
    ) AS shipments_without_sales_order;


/* ============================================================
   END OF PHASE 6D.5 — VERSION 1.0
   ============================================================ */
