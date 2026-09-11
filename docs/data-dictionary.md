# NovaMart Data Dictionary

This document describes the 14 production tables used in the NovaMart Supply Chain Intelligence project. It summarizes the purpose of each table, its key relationships, and the principal fields used for analysis.

---

## Master Tables

### `Categories`

**Purpose:** Stores NovaMart’s nine FMCG product categories.

**Primary Key:** `CategoryID`

**Key Fields:**
- `CategoryID` — unique category identifier
- `CategoryName` — category description

**Analytical Use:** Supports category-level analysis of sales, inventory, procurement, and estimated profitability.

---

### `Suppliers`

**Purpose:** Stores supplier master data.

**Primary Key:** `SupplierID`

**Key Fields:**
- `SupplierID`
- `SupplierName`

**Analytical Use:** Supports supplier spend, procurement concentration, reliability, and dependency analysis.

---

### `Products`

**Purpose:** Stores the product master and links products to categories.

**Primary Key:** `ProductID`

**Foreign Key:** `CategoryID`

**Key Fields Include:**
- `ProductID`
- `ProductName`
- `CategoryID`
- `StandardCost`

**Analytical Use:** Supports product revenue, unit demand, inventory, procurement, and 2025 estimated profitability analysis.

---

### `Warehouses`

**Purpose:** Stores NovaMart’s three warehouse locations and supporting warehouse information.

**Primary Key:** `WarehouseID`

**Key Fields Include:**
- `WarehouseID`
- `WarehouseName`
- warehouse capacity attributes

**Analytical Use:** Supports warehouse-level sales, inventory, service, and logistics analysis.

---

### `Customers`

**Purpose:** Stores customer master data and customer segmentation.

**Primary Key:** `CustomerID`

**Key Fields Include:**
- `CustomerID`
- customer name
- `CustomerType`

**Analytical Use:** Supports customer-level and segment-level revenue, order, and service analysis.

---

### `Employees`

**Purpose:** Stores employees associated with operational transactions.

**Primary Key:** `EmployeeID`

**Key Fields Include:**
- `EmployeeID`
- employee descriptive fields
- department information

**Analytical Use:** Maintains operational transaction ownership and relational integrity.

---

## Procurement Tables

### `PurchaseOrders`

**Purpose:** Stores purchase-order header information.

**Primary Key:** `PurchaseOrderID`

**Foreign Keys Include:**
- `SupplierID`
- `EmployeeID`

**Important Fields Include:**
- `PurchaseOrderDate`
- `ExpectedDeliveryDate`
- `ActualDeliveryDate`

**Analytical Use:** Supports purchase-order activity, supplier performance, lead-time, and supplier OTD analysis.

---

### `PurchaseOrderItems`

**Purpose:** Stores individual products and quantities contained in each purchase order.

**Primary Key:** purchase-order-item identifier

**Foreign Keys Include:**
- `PurchaseOrderID`
- `ProductID`

**Important Fields Include:**
- `QuantityOrdered`
- unit cost
- `LineTotal`

**Analytical Use:** Primary source for procurement spend, procurement units, product/category purchasing, and average procurement unit cost.

---

## Sales Tables

### `SalesOrders`

**Purpose:** Stores customer sales-order header information.

**Primary Key:** `SalesOrderID`

**Foreign Keys Include:**
- `CustomerID`
- `WarehouseID`
- `EmployeeID`

**Important Fields Include:**
- `OrderDate`
- `RequiredDeliveryDate`

**Analytical Use:** Supports order counts, customer and warehouse filtering, required delivery dates, and logistics service analysis.

---

### `SalesOrderItems`

**Purpose:** Stores individual products sold within each sales order.

**Primary Key:** sales-order-item identifier

**Foreign Keys Include:**
- `SalesOrderID`
- `ProductID`

**Important Fields Include:**
- `QuantitySold`
- selling-price fields
- `LineTotal`

**Analytical Use:** Primary source for revenue, units sold, product performance, category performance, and estimated profitability.

---

## Logistics Table

### `Shipments`

**Purpose:** Stores shipment and delivery activity associated with sales orders.

**Primary Key:** shipment identifier

**Foreign Key:** `SalesOrderID`

**Important Fields Include:**
- `ShipmentDate`
- `DeliveryDate`
- `TransportCost`
- delivery distance
- shipment-weight attributes

**Analytical Use:** Supports OTD, late-delivery analysis, transport cost, cost-per-shipment, cost-per-kilometer, and warehouse logistics analysis.

---

## Finance Table

### `Payments`

**Purpose:** Stores payment records associated with sales orders.

**Primary Key:** payment identifier

**Foreign Key:** `SalesOrderID`

**Important Fields Include:**
- `PaymentDate`
- `AmountPaid`
- `PaymentStatus`
- `PaymentMethod`

**Analytical Use:** Supports collected cash, collection rate, payment-status analysis, payment-method mix, and payment lag.

**Business Rule:** Collected Cash includes only records where:

> `PaymentStatus = "Paid"`

---

## Inventory Tables

### `InventoryTransactions`

**Purpose:** Stores historical inventory movements.

**Primary Key:** inventory-transaction identifier

**Foreign Keys Include:**
- `ProductID`
- `WarehouseID`

**Important Fields Include:**
- `TransactionDate`
- `Inventory Date`
- `TransactionType`
- stock movement quantity
- `StockAfter`

**Analytical Use:** Supports historical stock-out events, Stock-Out Rate, inventory movement analysis, and year-based inventory-transaction reporting.

---

### `Inventory`

**Purpose:** Stores the current product-by-warehouse inventory snapshot.

**Primary Grain:** one product × one warehouse position

**Foreign Keys Include:**
- `ProductID`
- `WarehouseID`

**Important Fields Include:**
- Quantity on Hand
- Reorder Level
- Safety Stock

**Analytical Use:** Supports:
- Current Inventory Units
- Current Inventory Value
- Inventory Positions
- Low Stock Positions
- Safety Stock exposure
- Zero Stock Positions
- Current Days of Supply

This table represents a **current snapshot** and should not be interpreted as a historical year-by-year inventory table.

---

## Relationship Summary

Master tables provide descriptive business context, while transactional tables store procurement, sales, inventory, logistics, and payment activity.

Products connect operational activity back to Categories, Customers connect to SalesOrders, Suppliers connect to PurchaseOrders, and Warehouses support location-level analysis across sales and inventory.

A dedicated Date table in Power BI provides controlled historical filtering across appropriate transactional dates.
