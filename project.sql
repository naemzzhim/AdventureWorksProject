use master 
go
use AdventureWorks2022
go
-- Truy vấn phân tích doanh thu bán hàng theo khu vực --
-- Mục tiêu: Phân tích bán hàng theo từng quốc gia, bang, thành phố và năm -- 
select * from Sales.SalesOrderHeader
select * from Sales.SalesTerritory
select * from Person.StateProvince
SELECT * from Person.Address
SELECT * from Person.CountryRegion

select pc.Name as Country,
        ps.Name as State ,
        pa.City,
        YEAR(soh.OrderDate) as OrderYear,
        SUM(soh.SubTotal) as TotalSales
from Sales.SalesOrderHeader soh 
LEFT join Sales.SalesTerritory st on soh.TerritoryID = st.TerritoryID
LEFT join Person.Address pa on soh.BillToAddressID = pa.AddressID
left join Person.StateProvince ps on pa.StateProvinceID = ps.StateProvinceID
left join Person.CountryRegion pc on ps.CountryRegionCode = pc.CountryRegionCode
GROUP by pc.Name, ps.Name, pa.City, YEAR(soh.OrderDate)
order by TotalSales desc; 

-- Phân tích nhóm khách hàng theo thời điểm mua hàng đầu tiên và phân tích mức độ quay lại mua sắm
with FirstPurchase as (
        select 
        CustomerID,
        MIN(OrderDate) as FirstOrderDate
        from Sales.SalesOrderHeader
        group by CustomerID
),
CohortAnalysis as(
        select f.CustomerID,
                DATEPART(year, f.FirstOrderDate) as CohortYear, 
                DATEPART(MONTH, f.FirstOrderDate) AS CohortMonth, 
                DATEPART(year, soh.OrderDate) as PurchaseYear,
                DATEPART(MONTH, soh.OrderDate) as PurchaseMonth,
                COUNT(soh.SalesOrderID) as PurchaseCount
        from FirstPurchase f 
        LEFT join Sales.SalesOrderHeader soh ON f.CustomerID = soh.CustomerID
        group by f.CustomerID, DATEPART(year, f.FirstOrderDate),
                DATEPART(month, f.FirstOrderDate),
                DATEPART(year, soh.OrderDate),
                DATEPART(MONTH, soh.OrderDate)
        
)

select  
        CohortYear, CohortMonth, PurchaseYear, PurchaseMonth,
        COUNT(CustomerID) as ActiveCustomers ,
        SUM(PurchaseCount) as TotalOrders
from CohortAnalysis 
group by CohortYear, CohortMonth, PurchaseYear, PurchaseMonth
order by CohortYear, CohortMonth, PurchaseYear, PurchaseMonth;

-- Truy vấn sản phảm bán chạy nhất và doanh thu cao nhất theo từng danh mục --
 select pp.Name as Product ,
        ppc.Name as ProductCategory,
        SUM(sod.OrderQty) as TotalQty,
        SUM(sod.LineTotal) as TotalSales
 from Sales.SalesOrderDetail sod
 INNER JOIN Production.Product pp on sod.ProductID = pp.ProductID
 INNER JOIN Production.ProductCategory ppc on pp.ProductSubcategoryID = ppc.ProductCategoryID
 group by pp.Name, ppc.Name
 order by SUM(sod.OrderQty) DESC

 -- Truy vấn tỉ lệ nhân viên nghỉ việc -- 
SELECT hd.Name,
        COUNT(he.BusinessEntityID) as ActiveEmployees,
        SUM(case when cast(DATEPART(year, hep.EndDate)as int) IS NOT NULL then 1 else 0 end) as EmployeeWhoLeft,
        ROUND(CAST(SUM(case when  cast(DATEPART(year, hep.EndDate)as int) IS NOT NULL then 1 else 0 end) as float)/COUNT(he.BusinessEntityID), 2) as AttritionTRate
from HumanResources.Employee he 
full join HumanResources.EmployeeDepartmentHistory hep on he.BusinessEntityID = hep.BusinessEntityID
full join HumanResources.Department hd on hd.DepartmentID = hep.DepartmentID 
group by hd.Name
ORDER BY AttritionTRate DESC

-- Truy vấn doanh thu trung bình của mỗi tuần -- 
with SalesData as (
        SELECT OrderDate,
                SUM(SubTotal) AS DailySales
        from Sales.SalesOrderHeader 
        group by OrderDate
),
MovingAvg as (
        SELECT OrderDate,
                DailySales,
                AVG(DailySales) OVER(order by OrderDate ROWS BETWEEN 6 preceding and current row) as MovingAvg7Days
        from SalesData
)

select *
from MovingAvg
order by OrderDate

-- Truy vấn RFM (Recency, Frequency, Monetary) Analysis --
with RFM as (
        SELECT CustomerID,
                DATEDIFF(day, MAX(OrderDate), GETDATE()) as Recency,
                COUNT(SalesOrderID) as Frequency,
                SUM(SubTotal) as Monetary
        from Sales.SalesOrderHeader 
        group by CustomerID
)       
SELECT CustomerID,
        Recency,
        Frequency,
        Monetary,
        case
                when Recency <= 30 then 'Active'
                when Recency <= 90 then 'At risk'
                else 'Churned'
        end as CustomerSegment
from RFM
order by Recency desc 

