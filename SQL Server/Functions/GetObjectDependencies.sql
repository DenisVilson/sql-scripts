/*
Author: Denis Vilson
Version: 1.0
Date: 2023-05-03
GitHub: https://github.com/DenisVilson/sql-scripts

Description: 
    This function returns a list of dependencies for a specified database object. 
    It allows filtering by dependency direction, dependency types, and system object exclusion.

Parameters:
    @ObjectName (NVARCHAR(128)): The name of the object for which to fetch dependencies, including schema, e.g., 'dbo.Object1'.
    
    @DependencyDirection (CHAR(1)): 'O' for outgoing dependencies (default), 'I' for incoming dependencies.
    
    @DependencyType (NVARCHAR(255)): A comma-separated list of dependency types to filter by,
                                     e.g., 'USER_TABLE,VIEW,SQL_STORED_PROCEDURE'. NULL (default) for all types.
                                     Applicable values include:
                                      - USER_TABLE
                                      - VIEW
                                      - SQL_STORED_PROCEDURE
                                      - SQL_SCALAR_FUNCTION
                                      - SQL_INLINE_TABLE_VALUED_FUNCTION
                                      - SQL_TABLE_VALUED_FUNCTION
                                      - CLR_SCALAR_FUNCTION
                                      - CLR_TABLE_VALUED_FUNCTION
                                      - CLR_STORED_PROCEDURE
    
    @ExcludeSystemObjects (BIT): 1 (default) to exclude system objects, 0 to include them.
*/
CREATE FUNCTION dbo.GetObjectDependencies
(
    @ObjectName NVARCHAR(128),
    @DependencyDirection CHAR(1) = 'O', -- 'O' for outgoing, 'I' for incoming
    @DependencyType NVARCHAR(255) = NULL, -- Filter by dependency types, separated by ',', e.g. 'USER_TABLE,VIEW,SQL_STORED_PROCEDURE', NULL for all types
    @ExcludeSystemObjects BIT = 1 -- 1 to exclude system objects, 0 to include them
)
RETURNS TABLE
AS
RETURN (
    WITH DependenciesCTE AS (
        SELECT
            OBJECT_SCHEMA_NAME(referencing_id) + '.' + OBJECT_NAME(referencing_id) AS referencing_object_name,
            referencing_id,
            referenced_schema_name + '.' + referenced_entity_name AS referenced_object_name,
            referenced_id
        FROM sys.sql_expression_dependencies
        WHERE (
                @DependencyDirection = 'O'
                AND OBJECT_SCHEMA_NAME(referencing_id) + '.' + OBJECT_NAME(referencing_id) = @ObjectName
              )
            OR (
                @DependencyDirection = 'I'
                AND referenced_schema_name + '.' + referenced_entity_name = @ObjectName
              )
    ),
    DependencyTypes AS (
        SELECT value AS type_desc
        FROM STRING_SPLIT(@DependencyType, ',')
    )
    SELECT
        d.referencing_object_name,
        o.type_desc AS referencing_object_type,
        d.referenced_object_name,
        ro.type_desc AS referenced_object_type
    FROM DependenciesCTE d
    INNER JOIN sys.objects o ON d.referencing_id = o.object_id
    INNER JOIN sys.objects ro ON d.referenced_id = ro.object_id
    WHERE (@DependencyType IS NULL OR ro.type_desc IN (SELECT type_desc FROM DependencyTypes))
        AND (o.is_ms_shipped = 0 OR @ExcludeSystemObjects = 0)
        AND (ro.is_ms_shipped = 0 OR @ExcludeSystemObjects = 0)
);
