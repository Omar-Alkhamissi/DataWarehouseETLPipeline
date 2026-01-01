CREATE TABLE DimProduct (
    ProductKey INT IDENTITY PRIMARY KEY,
    ProductName NVARCHAR(255),
    Brand NVARCHAR(255),
    Colour NVARCHAR(50),
    Price DECIMAL(10,2)
);

CREATE TABLE DimCustomer (
    CustomerKey INT IDENTITY PRIMARY KEY,
    CustomerName NVARCHAR(255),
    City NVARCHAR(255),
    StateProvince NVARCHAR(255),
    Country NVARCHAR(255)
);

CREATE TABLE DimSupplier (
    SupplierKey INT IDENTITY PRIMARY KEY,
    SupplierName NVARCHAR(255),
    SupplierCategory NVARCHAR(255),
    IsCurrentRecord BIT,
    StartDate DATETIME,
    EndDate DATETIME
);

CREATE TABLE DimSalesperson (
    SalespersonKey INT IDENTITY PRIMARY KEY,
    SalespersonName NVARCHAR(255),
    City NVARCHAR(255)
);

CREATE TABLE DimDate (
    DateKey INT IDENTITY PRIMARY KEY,
    FullDate DATE,
    DayOfWeek NVARCHAR(50),
    Month NVARCHAR(50),
    Year INT,
    IsHoliday BIT
);

/* FACT TABLE */
CREATE TABLE FactSales (
    SaleKey INT IDENTITY PRIMARY KEY,
    ProductKey INT,
    CustomerKey INT,
    SupplierKey INT,
    SalespersonKey INT,
    DateKey INT,
    Quantity INT,
    TotalAmount DECIMAL(10,2),
    FOREIGN KEY (ProductKey) REFERENCES DimProduct(ProductKey),
    FOREIGN KEY (CustomerKey) REFERENCES DimCustomer(CustomerKey),
    FOREIGN KEY (SupplierKey) REFERENCES DimSupplier(SupplierKey),
    FOREIGN KEY (SalespersonKey) REFERENCES DimSalesperson(SalespersonKey),
    FOREIGN KEY (DateKey) REFERENCES DimDate(DateKey)
);

/* INDEXES FOR OPTIMIZATION */
CREATE INDEX IX_ProductKey ON FactSales(ProductKey);
CREATE INDEX IX_CustomerKey ON FactSales(CustomerKey);
CREATE INDEX IX_SupplierKey ON FactSales(SupplierKey);
CREATE INDEX IX_SalespersonKey ON FactSales(SalespersonKey);
CREATE INDEX IX_DateKey ON FactSales(DateKey);


-- Populate DimSupplier
INSERT INTO DimSupplier (SupplierName, SupplierCategory, IsCurrentRecord, StartDate, EndDate)
VALUES
('Best Suppliers Inc.', 'Electronics', 1, '2023-01-01', NULL),
('Quality Supplies LLC', 'Accessories', 1, '2023-01-01', NULL),
('Global Distributors', 'Tech', 1, '2023-01-01', NULL);

-- Populate DimCustomer
INSERT INTO DimCustomer (CustomerName, City, StateProvince, Country)
VALUES 
('John Doe', 'New York', 'New York', 'United States'),
('Jane Smith', 'Los Angeles', 'California', 'United States'),
('Michael Brown', 'Chicago', 'Illinois', 'United States');

-- Populate DimProduct
INSERT INTO DimProduct (ProductName, Brand, Colour, Price)
VALUES 
('Laptop', 'TechBrand', 'Silver', 1200.00),
('Smartphone', 'PhoneBrand', 'Black', 800.00),
('Tablet', 'TabBrand', 'White', 600.00);

-- Populate DimSalesperson
INSERT INTO DimSalesperson (SalespersonName, City)
VALUES 
('Alice Johnson', 'New York'),
('Bob Williams', 'Los Angeles'),
('Charlie Davis', 'Chicago');

-- Populate DimDate
INSERT INTO DimDate (FullDate, DayOfWeek, Month, Year, IsHoliday)
VALUES 
('2024-01-01', 'Monday', 'January', 2024, 1),
('2024-01-02', 'Tuesday', 'January', 2024, 0),
('2024-01-03', 'Wednesday', 'January', 2024, 0);

-- Populate FactSales
INSERT INTO FactSales (ProductKey, CustomerKey, SupplierKey, SalespersonKey, DateKey, Quantity, TotalAmount)
VALUES 
(1, 1, 1, 1, 1, 5, 6000.00), -- Sale 1
(2, 2, 1, 2, 2, 3, 2400.00), -- Sale 2
(3, 3, 1, 3, 3, 7, 4200.00); -- Sale 3

SELECT * FROM FactSales;
SELECT * FROM DimCustomer;
SELECT * FROM DimProduct;
SELECT * FROM DimSalesperson;
SELECT * FROM DimDate;
GO

CREATE PROCEDURE sp_InsertDateDimension
    @DateValue DATE
AS
BEGIN
    INSERT INTO DimDate (FullDate, DayOfWeek, Month, Year, IsHoliday)
    VALUES (
        @DateValue,
        DATENAME(WEEKDAY, @DateValue),
        DATENAME(MONTH, @DateValue),
        YEAR(@DateValue),
        CASE WHEN @DateValue IN ('2024-01-01', '2024-12-25') THEN 1 ELSE 0 END
    );
END;

-- TEST: Insert into Date Dimension
PRINT 'Test: Insert Date Dimension';
EXEC sp_InsertDateDimension @DateValue = '2024-01-01';
SELECT * FROM DimDate WHERE FullDate = '2024-01-01';
GO

CREATE PROCEDURE sp_CompellingQuery AS
BEGIN
    SELECT
        C.CustomerName,
        C.City,
        S.SalespersonName,
        P.ProductName,
        P.Brand,
        P.Colour,
        SUM(FS.Quantity) AS TotalQuantitySold,
        SUM(FS.TotalAmount) AS TotalSales,
        D.Year,
        D.Month
    FROM FactSales FS
    JOIN DimCustomer C ON FS.CustomerKey = C.CustomerKey
    JOIN DimProduct P ON FS.ProductKey = P.ProductKey
    JOIN DimSalesperson S ON FS.SalespersonKey = S.SalespersonKey
    JOIN DimDate D ON FS.DateKey = D.DateKey
    GROUP BY
        C.CustomerName, C.City, S.SalespersonName, P.ProductName, P.Brand, P.Colour, D.Year, D.Month
    ORDER BY TotalSales DESC;
END;

-- TEST: Run Compelling Query
PRINT 'Test: Compelling Query';
EXEC sp_CompellingQuery;

CREATE TABLE StageCustomer (
    CustomerKey INT,
    CustomerName NVARCHAR(255),
    City NVARCHAR(255),
    StateProvince NVARCHAR(255),
    Country NVARCHAR(255)
);
GO

CREATE OR ALTER PROCEDURE sp_ExtractCustomerData AS
BEGIN
    -- Insert data into StageCustomer
    INSERT INTO StageCustomer (CustomerKey, CustomerName, City, StateProvince, Country)
    SELECT
        C.CustomerID AS CustomerKey,      
        C.CustomerName,                 
        CI.CityName,                    
        SP.StateProvinceName,            
        CO.CountryName                   
    FROM Sales.Customers C
    JOIN Application.Cities CI 
        ON C.DeliveryCityID = CI.CityID 
    JOIN Application.StateProvinces SP 
        ON CI.StateProvinceID = SP.StateProvinceID 
    JOIN Application.Countries CO 
        ON SP.CountryID = CO.CountryID;  
END;

-- TEST: Extract Customer Data
PRINT 'Test: Extract Customer Data';
EXEC sp_ExtractCustomerData;
SELECT * FROM StageCustomer;
GO

CREATE PROCEDURE sp_TransformCustomerData AS
BEGIN
    MERGE DimCustomer AS Target
    USING StageCustomer AS Source
    ON Target.CustomerName = Source.CustomerName
    WHEN MATCHED AND Target.City <> Source.City THEN
        UPDATE SET Target.City = Source.City
    WHEN NOT MATCHED THEN
        INSERT (CustomerName, City, StateProvince, Country)
        VALUES (Source.CustomerName, Source.City, Source.StateProvince, Source.Country);
END;

-- TEST: Transform Customer Data
PRINT 'Test: Transform Customer Data';
EXEC sp_TransformCustomerData;
SELECT * FROM DimCustomer;
GO

CREATE PROCEDURE sp_LoadCustomerDimension AS
BEGIN
    BEGIN TRANSACTION;

    BEGIN TRY
        EXEC sp_TransformCustomerData;
        COMMIT;
    END TRY
    BEGIN CATCH
        PRINT 'Error during transaction. Rolling back.';
        ROLLBACK;
    END CATCH;
END;

-- TEST: Load Customer Dimension
PRINT 'Test: Load Customer Dimension';	
EXEC sp_LoadCustomerDimension;
SELECT * FROM DimCustomer;

DECLARE @OrderDate DATE = '2013-01-01';
WHILE @OrderDate <= '2013-01-04'
BEGIN
    EXEC sp_ExtractCustomerData;
    EXEC sp_LoadCustomerDimension;
    SET @OrderDate = DATEADD(DAY, 1, @OrderDate);
END;

-- TEST: Run Compelling Query
PRINT 'Test: Query After ETL';
EXEC sp_CompellingQuery;
