IF NOT EXISTS(SELECT * FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = 'stg_dimemp')
	SELECT de.EmployeeKey as 'employee_key', de.FirstName as 'first_name', de.LastName as 'last_name', de.Title as 'title' INTO AdventureWorksDW2019.dbo.stg_dimemp FROM AdventureWorksDW2019.dbo.DimEmployee de
	WHERE de.EmployeeKey >= 270 AND de.EmployeeKey <=275;
ELSE
	DROP TABLE AdventureWorksDW2019.dbo.stg_dimemp;

	SELECT de.EmployeeKey as 'employee_key', de.FirstName as 'first_name', de.LastName as 'last_name', de.Title as 'title' INTO AdventureWorksDW2019.dbo.stg_dimemp FROM AdventureWorksDW2019.dbo.DimEmployee de
	WHERE de.EmployeeKey >= 270 AND de.EmployeeKey <=275;


SELECT de.EmployeeKey as 'employee_key', de.FirstName as 'first_name', de.LastName as 'last_name', de.Title as 'title', de.StartDate, de.EndDate INTO AdventureWorksDW2019.dbo.scd_dimemp 
FROM AdventureWorksDW2019.dbo.DimEmployee de;

DROP TABLE AdventureWorksDW2019.dbo.scd_dimemp;
CREATE TABLE AdventureWorksDW2019.dbo.scd_dimemp (
EmployeeKey int ,
FirstName nvarchar(50) not null,
LastName nvarchar(50) not null,
Title nvarchar(50),
StartDate datetime,
EndDate datetime,
PRIMARY KEY(EmployeeKey)
);

INSERT INTO scd_dimemp(EmployeeKey, FirstName, LastName, Title, StartDate, EndDate)
SELECT de.EmployeeKey, de.FirstName, de.LastName, de.Title, de.StartDate, de.EndDate FROM DimEmployee de
WHERE de.EmployeeKey >= 270 AND de.EmployeeKey <= 275;

SELECT * FROM scd_dimemp;
SELECT * FROM stg_dimemp;

update stg_dimemp
set last_name = 'Nowakiewicz'
where employee_key = 270;
-- Typ pierwszy Slowly Changing Dimensions. W tym przypadku tracimy dane poniewa¿ nadpisujemy nowe nazwisko i stare nazwisko nigdzie nie jest przechowywane.
update stg_dimemp
set title = 'Senior Design Engineer'
where employee_key = 274;
-- Typ drugi Slowly Chaning Dimensions. W g³ownej tabeli w tym przypadku tytu³ pracownika zosta³ nadpisany, ale w tabeli SCD pozostaje poprzednie stanowisko przed zmian¹ razem z dat¹ kiedy dosz³o do zmiany stanowiska.
update stg_dimemp
set first_name = 'Nikodem'
where employee_key = 275;
-- Typ trzeci SLowly Changing Dimensions. W g³ownej tabeli zmienamy imiê i tam sie aktualizuje, ale w tabeli SCD pozostaje stare imiê.
-- Wp³yw na t¹ opcje by³o zaznaczenie kwadracika: "Fail the transformation if changes are detected in fixed attribute" oraz wybranie dla kolumny first_name typu "Fixed Column"

SELECT * FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = 'stg_dimemp';