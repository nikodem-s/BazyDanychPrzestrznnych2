GO
CREATE PROCEDURE filter_date @yearsAgo INT
AS
SELECT fct.CurrencyKey, dc.CurrencyAlternateKey, fct.AverageRate, fct.Date FROM FactCurrencyRate fct INNER JOIN DimCurrency dc ON fct.CurrencyKey=dc.CurrencyKey WHERE DATEDIFF(YEAR, fct.Date, GETDATE()) > @yearsAgo AND (dc.CurrencyAlternateKey='GBP' OR dc.CurrencyAlternateKey='EUR');
GO