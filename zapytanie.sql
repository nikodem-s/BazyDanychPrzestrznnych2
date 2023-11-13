
SELECT fis.OrderDate, COUNT(*) AS 'ilosc zamowien' FROM FactInternetSales fis GROUP BY fis.OrderDate HAVING COUNT(*)<100 ORDER BY COUNT(*) ASC;


WITH HighestValuesForUnitPrice AS
(
   SELECT fis.OrderDate,fis.UnitPrice,
         ROW_NUMBER() OVER (PARTITION BY OrderDate ORDER BY UnitPrice DESC) AS top_sales
   FROM FactInternetSales fis
)
SELECT  OrderDate, UnitPrice
FROM HighestValuesForUnitPrice
WHERE top_sales <=3;