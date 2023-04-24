/*
Description: This script retrieves the count of rows for each table in a specified schema where a given column meets a specific condition.
Author: Denis Vilson
Version: 1.0
Date: 2023-04-24
GitHub: https://github.com/DenisVilson/sql-scripts
*/

-- The schema name to search for tables
DECLARE @schema_name VARCHAR(128) = 'dbo';

-- The column filter condition to filter tables by the presence of a specific column
DECLARE @column_filter_condition VARCHAR(256) = '1 = 1';

-- The row filter condition to filter rows within each table based on a specific condition
DECLARE @row_filter_condition NVARCHAR(256) = '1 = 1';

DECLARE @table_name VARCHAR(128);

-- Construct the dynamic SQL query to retrieve filtered tables
DECLARE @query NVARCHAR(MAX);
SET @query = '
    SELECT DISTINCT TABLE_NAME
    FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_SCHEMA = ''' + @schema_name + ''' AND ' + @column_filter_condition + ';';

-- Table variable to store the filtered table names
DECLARE @FilteredTables TABLE (TABLE_NAME NVARCHAR(128));

-- Execute the dynamic SQL query and store the results in the table variable
INSERT INTO @FilteredTables (TABLE_NAME)
EXEC sp_executesql @query;

-- Declare the cursor to iterate through the filtered table names
DECLARE tab_cursor CURSOR FOR
SELECT TABLE_NAME FROM @FilteredTables;

OPEN tab_cursor;
FETCH NEXT FROM tab_cursor INTO @table_name;

-- Iterate through the filtered tables and retrieve the row count based on the row filter condition
WHILE @@FETCH_STATUS = 0
BEGIN
    DECLARE @sql NVARCHAR(1000);
    SET @sql = 'SELECT @count = COUNT(*) FROM ' + QUOTENAME(@schema_name) + '.' + QUOTENAME(@table_name) + ' WHERE ' + @row_filter_condition;

    DECLARE @count INT;
    EXECUTE sp_executesql @sql, N'@count INT OUTPUT', @count = @count OUTPUT;

    -- Print the table name and the row count
    PRINT @table_name + ': ' + CAST(@count AS VARCHAR);

    FETCH NEXT FROM tab_cursor INTO @table_name;
END;

-- Close and deallocate the cursor
CLOSE tab_cursor;
DEALLOCATE tab_cursor;
