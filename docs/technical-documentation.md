# NovaMart Technical Documentation

## 1. Technical Architecture Overview

NovaMart was designed as an end-to-end analytics solution with four main layers:

### 1.1 Operational Data Layer
A MySQL relational database stores the simulated operational data across sales, procurement, inventory, logistics, finance, customers, products, suppliers, employees, and warehouses.

### 1.2 SQL Analysis Layer
Modular SQL scripts transform operational records into validated business metrics and analytical outputs across six major workstreams.

### 1.3 Semantic / KPI Layer
Power BI imports the relational model and applies governed DAX measures for executive KPIs, diagnostics, and interactive analysis.

### 1.4 Presentation Layer
A seven-page Power BI report presents executive and operational insights through KPI cards, trends, rankings, scatter plots, filters, tooltips, and drill-through pages.

The architecture can therefore be summarized as:

> **MySQL Database → SQL Analysis → Power BI Data Model → DAX Measures → Interactive Dashboard**

---

## 2. Database & Data Model Documentation

The NovaMart database contains **14 production tables**.

### Master Tables
- Categories
- Suppliers
- Products
- Warehouses
- Customers
- Employees

### Procurement Tables
- PurchaseOrders
- PurchaseOrderItems

### Sales Tables
- SalesOrders
- SalesOrderItems

### Logistics
- Shipments

### Finance
- Payments

### Inventory
- InventoryTransactions
- Inventory

The model separates master data from transactional activity and uses relational keys to connect business entities to operational events.

### Primary Analytical Relationships
- Categories → Products
- Products → SalesOrderItems
- Products → PurchaseOrderItems
- Products → InventoryTransactions
- Products → Inventory
- Customers → SalesOrders
- Warehouses → SalesOrders
- Employees → SalesOrders
- Suppliers → PurchaseOrders
- Employees → PurchaseOrders
- SalesOrders → SalesOrderItems
- SalesOrders → Shipments
- SalesOrders → Payments
- PurchaseOrders → PurchaseOrderItems
- Warehouses → InventoryTransactions
- Warehouses → Inventory

A dedicated Date table supports time-based analysis across the model.

Active and inactive date relationships are used deliberately depending on the business event being analyzed, including:
- Order Date
- Purchase Order Date
- Inventory Transaction Date
- Required Delivery Date
- Expected Delivery Date
- Actual Delivery Date
- Payment Date
- Shipment Date
- Delivery Date

The final inventory-date relationship was standardized through a clean date-only key so annual inventory-transaction analysis filters correctly by year.

---

## 3. Dataset Scale

The validated production dataset includes:

- 9 categories
- 24 suppliers
- 90 products
- 3 warehouses
- 600 customers
- 120 employees
- 4,500 purchase orders
- 14,023 purchase-order items
- 30,000 sales orders
- 150,000 sales-order items
- 30,000 shipments
- 30,000 payment records
- 197,854 inventory transactions
- 270 current inventory positions

The production dataset passed the final data-quality and validation checks before analytical development began.

---

## 4. Data Modeling Principles

The model follows several governance principles:

- single source for each KPI definition
- no duplicated analytical logic across pages
- explicit relationship direction
- controlled use of inactive relationships
- separation of current inventory snapshot metrics from historical transactional metrics
- estimated profitability limited to periods supported by the available cost structure
- no double counting of orders, shipments, payments, or procurement records

These principles help ensure that the model is not only functional, but trustworthy and auditable.

---

## 5. SQL Analysis Architecture

NovaMart’s SQL analysis was organized into a structured architecture designed to separate raw operational data from business-facing insights.

The SQL workflow used four conceptual layers:

### 5.1 Operational Database Layer
Contains the validated production tables stored in MySQL and serves as the source of truth for transactional and master data.

### 5.2 Analysis Base Layer
Prepares operational data for analysis by joining related tables, applying business rules, and establishing the correct analytical grain.

### 5.3 KPI & Analysis Layer
Calculates business metrics, comparisons, rankings, trends, service levels, cost indicators, and diagnostic measures.

### 5.4 Business Insight Layer
Converts analytical outputs into interpretable findings that support management decisions and later feed the Power BI dashboard.

The architecture can be summarized as:

> **Operational Tables → Analytical Joins & Business Logic → KPI Calculations → Business Insights**

### 5.5 Six SQL Analysis Modules

#### 1. Sales Performance
**File:** `01_sales_performance.sql`

Covers:
- Total Revenue
- Sales Orders
- Units Sold
- Average Order Value
- Revenue Growth
- Annual Revenue Performance
- Monthly Revenue Trends
- Warehouse Revenue Performance
- Order and demand growth

#### 2. Product & Customer Performance
**File:** `02_product_customer_performance_v1.1.sql`

Covers:
- Revenue by Category
- Revenue by Product
- Top Products
- Customer Segment Performance
- Top Customers
- Revenue Concentration
- Unit Demand
- 2025 Estimated Gross Profit
- 2025 Estimated Gross Margin

Historical profitability was deliberately not calculated for periods where the available cost structure could not support a defensible estimate.

#### 3. Inventory Intelligence
**File:** `03_inventory_intelligence_v1.0.sql`

Covers:
- Current Inventory Units
- Current Inventory Value
- Inventory Positions
- Stock-Out Events
- Stock-Out Rate
- Reorder-Level Exposure
- Safety-Stock Exposure
- Days of Supply
- Inventory Turnover
- Days Inventory
- Warehouse Inventory Distribution
- Category Inventory Concentration

This module combines current inventory snapshot analysis with historical inventory-transaction analysis while keeping the two concepts separate.

#### 4. Procurement & Supplier Performance
**File:** `04_procurement_supplier_v1.0.sql`

Covers:
- Procurement Spend
- Purchase Orders
- Units Procured
- Average Procurement Unit Cost
- Procurement Spend Growth
- Supplier Spend
- Supplier Spend Concentration
- Supplier On-Time Delivery
- Category Procurement Spend
- Supplier Dependency
- High-Spend / Low-Reliability Supplier Risk

The module also includes reconciliation checks to ensure procurement totals remain internally consistent.

#### 5. Logistics & Service Performance
**File:** `05_logistics_service_v1.0.sql`

Covers:
- Shipment Count
- On-Time Delivery Rate
- Late Shipments
- Delivery Delay
- Warehouse OTD
- Customer Segment OTD
- Transport Cost
- Average Transport Cost per Shipment
- Transport Cost per Kilometer
- Transport Cost by Warehouse
- Cost–Distance Relationship
- Cost–Weight Relationship

The analysis identified delivery distance as the strongest observable driver of transport cost.

#### 6. Financial & Operational Efficiency
**File:** `06_financial_operational_efficiency_v1.1.sql`

Covers:
- Collected Cash
- Collection Rate
- Payment Status
- Payment Method
- Payment Lag
- Procurement Spend Intensity
- Transport Cost Ratio
- Revenue Growth versus Cost Growth
- 2025 Estimated Gross Profit
- 2025 Estimated Gross Margin
- Estimated Contribution After Transport
- Estimated Contribution Margin
- Revenue per Transport Naira
- Warehouse Contribution Analysis

Collected Cash is based only on payments with `PaymentStatus = "Paid"`.

**Estimated Contribution After Transport** is not presented as operating profit or net profit.

### 5.6 SQL Design Principles
- each module serves one defined analytical workstream
- KPI logic is calculated once and reused consistently
- joins are designed around the correct business grain
- aggregate totals are reconciled against source tables
- historical and current-snapshot metrics are not mixed incorrectly
- profitability terminology reflects the limits of the available cost data
- no unsupported cost allocations are introduced
- no double counting of orders, shipments, payments, or procurement activity

---

## 6. KPI & DAX Framework

The Power BI KPI layer was designed to reproduce the validated SQL business logic while supporting interactive filtering, drill-through analysis, and dashboard presentation.

A dedicated **Measures** table was used to centralize all DAX calculations.

### 6.1 Sales KPIs
- Total Revenue
- Sales Orders
- Units Sold
- Average Order Value
- Previous Year Revenue
- Revenue Growth %

### 6.2 Procurement KPIs
- Procurement Spend
- Purchase Orders
- Units Procured
- Average Procurement Unit Cost
- Average Purchase Order Value
- Supplier On-Time Purchase Orders
- Delivered Purchase Orders
- Supplier OTD %

### 6.3 Logistics KPIs
- Transport Cost
- Shipments Count
- On-Time Shipments
- Late Shipments
- On-Time Delivery Rate
- Average Transport Cost per Shipment
- Transport Cost per Kilometer
- Transport Cost Ratio

### 6.4 Payment & Collection KPIs
- Total Recorded Payment Value
- Collected Cash
- Uncollected Value
- Collection Rate %
- Paid Payment Records

Collected Cash includes only records where:

> `PaymentStatus = "Paid"`

Pending and Failed payment records are excluded from collected cash.

### 6.5 Inventory KPIs
- Current Inventory Units
- Current Inventory Value
- Inventory Positions
- Positions At or Below Reorder
- Positions At or Below Safety Stock
- Zero Stock Positions
- Stock-Out Events
- Sales Shipment Inventory Transactions
- Stock-Out Rate %
- Low Stock Positions
- Current Days of Supply

Current inventory metrics are intentionally treated as **present-state snapshot measures**, while stock-out measures are based on historical InventoryTransactions.

### 6.6 2025 Estimated Profitability KPIs
Because the available product standard cost supports defensible profitability analysis only for 2025, the following measures are explicitly restricted to that year:

- Revenue 2025
- Estimated COGS 2025
- Estimated Gross Profit 2025
- Estimated Gross Margin % 2025
- Transport Cost 2025
- Estimated Contribution After Transport 2025
- Estimated Contribution Margin % 2025

The term **Estimated Contribution After Transport** is used deliberately and is not treated as operating profit or net profit.

### 6.7 Cross-Functional Efficiency KPIs
- Procurement Spend Intensity %
- Revenue per Transport Naira

### 6.8 DAX Governance Principles
- KPI definitions are aligned with validated SQL calculations
- measures are centralized in one Measures table
- business logic is not duplicated unnecessarily
- current-snapshot and historical metrics remain conceptually separate
- profitability measures are limited to periods supported by valid cost data
- relationship context is respected rather than bypassed arbitrarily
- measures are validated against SQL benchmarks before dashboard release
- display formatting is separated from underlying numerical logic where necessary

### 6.9 SQL-to-Power BI Reconciliation
Major DAX measures were reconciled with SQL outputs, including:

- Total Revenue
- Sales Orders
- Units Sold
- Procurement Spend
- Transport Cost
- Supplier OTD
- On-Time Delivery Rate
- Collection Rate
- Current Inventory Units
- Current Inventory Value
- Stock-Out Rate
- Estimated Gross Margin
- Estimated Contribution After Transport

---

## 7. Power BI Model & Relationships

The NovaMart Power BI model was designed as a relational semantic layer that preserves the structure of the MySQL database while supporting time intelligence, cross-functional analysis, drill-through, and interactive filtering.

### 7.1 Core Active Relationships
- `Categories[CategoryID]` → `Products[CategoryID]`
- `Products[ProductID]` → `SalesOrderItems[ProductID]`
- `Products[ProductID]` → `PurchaseOrderItems[ProductID]`
- `Products[ProductID]` → `InventoryTransactions[ProductID]`
- `Products[ProductID]` → `Inventory[ProductID]`
- `Customers[CustomerID]` → `SalesOrders[CustomerID]`
- `Warehouses[WarehouseID]` → `SalesOrders[WarehouseID]`
- `Employees[EmployeeID]` → `SalesOrders[EmployeeID]`
- `Suppliers[SupplierID]` → `PurchaseOrders[SupplierID]`
- `Employees[EmployeeID]` → `PurchaseOrders[EmployeeID]`
- `SalesOrders[SalesOrderID]` → `SalesOrderItems[SalesOrderID]`
- `SalesOrders[SalesOrderID]` → `Shipments[SalesOrderID]`
- `SalesOrders[SalesOrderID]` → `Payments[SalesOrderID]`
- `PurchaseOrders[PurchaseOrderID]` → `PurchaseOrderItems[PurchaseOrderID]`
- `Warehouses[WarehouseID]` → `InventoryTransactions[WarehouseID]`
- `Warehouses[WarehouseID]` → `Inventory[WarehouseID]`

The SalesOrders-to-Shipments relationship is valid as a one-to-one relationship in the final dataset because each sales order maps to exactly one shipment.

### 7.2 Date Table Design
A dedicated Date table supports historical analysis between 2023 and 2025.

The Date table contains fields such as:
- Date
- Year
- Month
- Month Number
- Month Short
- Month Year
- Quarter
- Year Quarter

Month fields are sorted using dedicated numeric sort columns to ensure chronological presentation in Power BI visuals.

### 7.3 Active Date Relationships
- `Date[Date]` → `SalesOrders[OrderDate]`
- `Date[Date]` → `PurchaseOrders[PurchaseOrderDate]`
- `Date[Date]` → `InventoryTransactions[Inventory Date]`

For inventory transactions, a dedicated date-only field was used to ensure that annual filtering from the Date table correctly propagates into historical inventory measures.

### 7.4 Inactive Date Relationships
- Date → SalesOrders Required Delivery Date
- Date → PurchaseOrders Expected Delivery Date
- Date → PurchaseOrders Actual Delivery Date
- Date → Payments Payment Date
- Date → Shipments Shipment Date
- Date → Shipments Delivery Date

These relationships remain available for calculations that explicitly require those alternative business dates.

### 7.5 Ambiguity Control
Important modeling decisions included:

- deactivating the direct `Warehouses → Shipments` relationship to avoid multiple active warehouse-filter paths
- deactivating the automatically generated `Customers → Payments` relationship so that payments are filtered consistently through SalesOrders
- preserving a single governed filter path wherever multiple potential relationships could create ambiguous results
- rebuilding the InventoryTransactions date relationship after validation revealed that Date filters were not propagating correctly

### 7.6 Filter Direction
Relationships are generally designed with controlled single-direction filtering from master/dimension-style tables toward transactional tables.

Bidirectional filtering is avoided unless the underlying relationship and analytical requirement justify it.

### 7.7 Drill-Through Structure

#### Product Detail
- uses Product Name as the drill-through field
- provides product-specific revenue, demand, inventory, and related analytical context

#### Supplier Detail
- uses Supplier Name as the drill-through field
- provides supplier-specific procurement spend, reliability, and supporting performance metrics

Both pages include Back navigation for returning to the source report page.

### 7.8 Tooltip Structure
A dedicated hidden Product Tooltip page provides additional product-level context when users hover over supported visuals.

### 7.9 Navigation & Slicer Behavior
The final report uses:

- a standardized page navigator across the seven main report pages
- synchronized Year slicers where historical comparison is appropriate
- synchronized Warehouse and Category slicers where relevant
- local specialized slicers such as Supplier, Product, and Payment Method
- deliberately unsynchronized current inventory behavior where a historical Year filter would not conceptually apply

### 7.10 Relationship Governance Principles
- one clear active filter path wherever possible
- inactive relationships used deliberately, not accidentally
- no duplicate dimensional paths that distort measures
- Date filtering governed through a dedicated calendar table
- current inventory snapshot behavior kept separate from historical transactional analysis
- all major relationship decisions validated against SQL outputs before final release

---

## 8. Validation & QA Methodology

NovaMart used a multi-stage validation approach to ensure that the final Power BI report remained consistent with the validated MySQL database and SQL analysis outputs.

The QA process focused on four areas: **data integrity, KPI reconciliation, relationship behavior, and report interaction testing**.

### 8.1 Data Validation
Before Power BI development, the production dataset was validated in MySQL.

Validation included:
- expected table row counts
- referential integrity
- duplicate records
- invalid or missing key fields
- date consistency
- inventory balance logic
- purchase-order consistency
- shipment-to-order consistency
- payment-record consistency

### 8.2 SQL Reconciliation
Each SQL analysis module included reconciliation checks to verify that aggregated analytical outputs remained consistent with the underlying transactional tables.

Examples included:
- total sales revenue reconciling to SalesOrderItems
- procurement spend reconciling to PurchaseOrderItems
- shipment counts reconciling to SalesOrders
- payment totals reconciling to payment-status logic
- inventory metrics reconciling to inventory and inventory-transaction data

### 8.3 DAX-to-SQL Reconciliation
Major KPIs compared directly with validated SQL results included:
- Total Revenue
- Sales Orders
- Units Sold
- Average Order Value
- Procurement Spend
- Purchase Orders
- Units Procured
- Supplier OTD %
- Shipments Count
- On-Time Delivery Rate
- Transport Cost
- Collection Rate %
- Current Inventory Units
- Current Inventory Value
- Stock-Out Rate %
- Estimated Gross Margin % 2025
- Estimated Contribution After Transport 2025

### 8.4 Filter-Context Testing
Dashboard slicers were tested to confirm that measures responded only where conceptually appropriate.

Tests included:
- Year filtering
- Warehouse filtering
- Category filtering
- Customer Type filtering
- Supplier filtering
- Product filtering
- Payment Method filtering

Special attention was given to current inventory measures, which were intentionally treated as present-state snapshot metrics rather than historical year-based measures.

### 8.5 Relationship Validation
Relationships were tested for:
- correct active and inactive states
- correct filter direction
- duplicate filter paths
- ambiguous relationships
- unexpected cross-filtering
- one-to-one versus one-to-many behavior

### 8.6 Drill-Through & Tooltip Testing
The Product Detail and Supplier Detail drill-through pages were tested using known products and suppliers.

Checks included:
- correct selected entity context
- correct KPI response
- correct navigation back to source pages
- correct tooltip behavior on supported product visuals

### 8.7 Page-by-Page Dashboard QA
All seven report pages were validated against expected SQL benchmarks:
- Executive Overview
- Sales Performance
- Product & Customer Performance
- Inventory Intelligence
- Procurement & Supplier Performance
- Logistics & Service Performance
- Financial & Operational Efficiency

Each page was checked for:
- correct KPI totals
- expected rankings
- historical trends
- slicer response
- warehouse and category behavior
- number formatting
- visual consistency

### 8.8 Final Issue Resolution
The final unresolved QA issue involved the **Stock-Out Rate Trend**.

The measure totals were correct overall, but Date filters initially failed to propagate properly into InventoryTransactions, causing repeated grand totals instead of year-specific values.

The issue was diagnosed using temporary table visuals and resolved by rebuilding the Date-to-InventoryTransactions relationship using a clean date-only inventory transaction field.

After correction, annual Stock-Out Rates displayed correctly at approximately:
- 2023: **0.64%**
- 2024: **0.30%**
- 2025: **0.13%**

### 8.9 QA Governance Principle
> **Every major dashboard KPI and analytical result should be traceable back to validated source data and reconciled SQL logic.**

---

## 9. Tools & Technologies

### MySQL 8.0+
Used to:
- store the 14-table production dataset
- enforce relational structure through keys and relationships
- support SQL-based analytical querying
- validate transactional and master data
- perform reconciliation and integrity checks

The production database used:
- InnoDB storage engine
- `utf8mb4` character encoding

### MySQL Workbench
Used for:
- database creation and schema management
- execution of analytical SQL scripts
- validation queries
- result inspection
- exporting analytical outputs
- troubleshooting data-loading and connection issues

### Power BI Desktop
Used for:
- importing the MySQL relational model
- managing table relationships
- creating the dedicated Date table
- building governed DAX measures
- implementing slicers and filter context
- creating drill-through pages
- creating tooltip pages
- designing the seven-page analytical report
- validating Power BI outputs against SQL benchmarks

### DAX
Used to build the Power BI KPI and analytical measure layer.

### Power Query
Used primarily during data import and preparation for:
- reviewing imported structures
- confirming data types
- preparing fields required for the Power BI model

Core business KPIs were not calculated in Power Query.

### ODBC / MySQL Connector
Used to connect Power BI to the `novamart_supply_chain` MySQL database.

A restricted Power BI database user was used to provide analytical access without unnecessary modification privileges.

### Microsoft Excel
Used as a supporting analytical and validation tool for:
- reviewing exported SQL outputs
- storing intermediate analytical results
- comparing query outputs
- assisting with manual reconciliation

### CSV
Used during dataset creation, loading, and validation as an interchange format between generated production data and MySQL.

### Supporting Technical Concepts
The project also demonstrates:
- relational database design
- data modeling
- SQL aggregation and joins
- KPI governance
- filter context
- time intelligence
- dimensional filtering
- data-quality validation
- analytical reconciliation
- dashboard design
- drill-through analysis
- business storytelling

### Technology Stack Summary
> **CSV / Structured Data → MySQL → SQL Analysis → ODBC → Power BI → DAX → Interactive Business Intelligence Dashboard**

---

## 10. Project Workflow Summary

NovaMart was developed through a structured, phased workflow designed to move from business definition to a validated, presentation-ready business intelligence solution.

### Phase 1 — Business Definition & Scope
Defined NovaMart as a simulated national FMCG distributor operating across Lagos, Abuja, and Port Harcourt.

Established:
- company structure
- business functions
- product categories
- customer segments
- warehouse locations
- analytical objectives
- project boundaries

### Phase 2 — Database & Schema Design
Designed a relational model around 14 production tables covering:
- master data
- procurement
- sales
- logistics
- finance
- inventory

### Phase 3 — Dataset Generation & Quality Correction
Generated the simulated production dataset and corrected inventory and procurement logic.

This stage included:
- full dataset creation
- correction of inventory and procurement logic
- controlled stock-out behavior
- validation of table sizes
- relational consistency checks
- final production dataset versioning

### Phase 4 — MySQL Loading & Validation
Loaded the production files into the `novamart_supply_chain` database.

Validation included:
- successful table loading
- expected row counts
- referential integrity
- duplicate checks
- date consistency
- order and shipment consistency
- inventory validation
- payment consistency

### Phase 5 — Analytical Foundation & Data Quality Assurance
Reviewed the validated operational database to confirm that business rules behaved realistically and supported the intended analytical questions.

This included confirming:
- inventory balances
- stock-out behavior
- procurement patterns
- sales volume
- warehouse activity
- transaction chronology

### Phase 6 — SQL Business Analysis
Developed six modular SQL workstreams:

1. Sales Performance
2. Product & Customer Performance
3. Inventory Intelligence
4. Procurement & Supplier Performance
5. Logistics & Service Performance
6. Financial & Operational Efficiency

Important methodological corrections included:
- limiting estimated profitability analysis to 2025
- removing unsupported category-level transport-cost allocation

### Phase 7 — Power BI Data Model & Dashboard Development
Imported the validated MySQL database into Power BI through ODBC.

This stage included:
- loading all 14 production tables
- creating the Date table
- configuring active and inactive relationships
- resolving ambiguous filter paths
- creating a centralized Measures table
- building DAX KPIs
- reconciling DAX with SQL outputs
- designing the seven-page report
- implementing synchronized slicers
- building drill-through pages
- creating tooltips
- implementing page navigation
- testing interactions
- validating every major dashboard output
- completing final UI polish

The Power BI solution was then frozen as the validated **v1.0 portfolio release**.

### Phase 8 — Portfolio Packaging & Documentation
The final stage converts the technical solution into a professional portfolio asset.

This includes:
- executive project narrative
- management insights and recommendations
- technical documentation
- GitHub repository organization
- README development
- portfolio visuals
- CV positioning
- LinkedIn positioning
- interview preparation
- final project release packaging

### End-to-End Workflow
> **Business Problem Definition → Relational Database Design → Dataset Generation → Data Validation → SQL Analysis → KPI Governance → Power BI Modeling → DAX Development → Dashboard Design → QA Reconciliation → UI Polish → Portfolio Documentation & Release**

The report is the final presentation layer of a broader analytical system built on validated data, governed business logic, and structured analysis.
