/*
Description: This script finds the relationships between two specified tables using foreign keys, considering a maximum number of intermediate tables and an option to exclude self-referencing links.
Author: Denis Vilson
Version: 1.0
Date: 2023-04-20
GitHub: https://github.com/DenisVilson/sql-scripts
*/

DECLARE @SourceTable NVARCHAR(128) = 'dbo.TableA';
DECLARE @TargetTable NVARCHAR(128) = 'dbo.TableB';
DECLARE @MaxTablesBetween INT = 3; -- Set the maximum number of tables allowed between the specified tables.
DECLARE @ExcludeSelfLinks BIT = 1; -- Set to 1 to exclude self-referencing links, 0 to include them.

WITH ForeignKeyGraph AS (
    SELECT 
        f.name AS ForeignKeyName,
        OBJECT_SCHEMA_NAME(f.parent_object_id) + '.' + OBJECT_NAME(f.parent_object_id) AS ReferencingTable,
        COL_NAME(fc.parent_object_id, fc.parent_column_id) AS ReferencingColumn,
        OBJECT_SCHEMA_NAME(f.referenced_object_id) + '.' + OBJECT_NAME(f.referenced_object_id) AS ReferencedTable,
        COL_NAME(fc.referenced_object_id, fc.referenced_column_id) AS ReferencedColumn,
        1 AS LinkLevel,
        CONVERT(NVARCHAR(MAX), OBJECT_SCHEMA_NAME(f.parent_object_id) + '.' + OBJECT_NAME(f.parent_object_id) + ' -> ' + OBJECT_SCHEMA_NAME(f.referenced_object_id) + '.' + OBJECT_NAME(f.referenced_object_id)) AS LinkChain
    FROM sys.foreign_keys AS f
    INNER JOIN sys.foreign_key_columns AS fc ON f.OBJECT_ID = fc.constraint_object_id
    WHERE (@ExcludeSelfLinks = 0) OR (f.parent_object_id <> f.referenced_object_id) -- Filter self-referencing links based on the @ExcludeSelfLinks variable.

    UNION ALL

    SELECT 
        f.name AS ForeignKeyName,
        g.ReferencingTable,
        g.ReferencingColumn,
        OBJECT_SCHEMA_NAME(f.referenced_object_id) + '.' + OBJECT_NAME(f.referenced_object_id) AS ReferencedTable,
        COL_NAME(fc.referenced_object_id, fc.referenced_column_id) AS ReferencedColumn,
        g.LinkLevel + 1 AS LinkLevel,
        CONVERT(NVARCHAR(MAX), g.LinkChain + ' -> ' + OBJECT_SCHEMA_NAME(f.referenced_object_id) + '.' + OBJECT_NAME(f.referenced_object_id)) AS LinkChain
    FROM ForeignKeyGraph AS g
    INNER JOIN sys.foreign_keys AS f ON SUBSTRING(g.ReferencedTable, CHARINDEX('.', g.ReferencedTable) + 1, LEN(g.ReferencedTable)) = OBJECT_NAME(f.parent_object_id)
                                      AND LEFT(g.ReferencedTable, CHARINDEX('.', g.ReferencedTable) - 1) = OBJECT_SCHEMA_NAME(f.parent_object_id)
    INNER JOIN sys.foreign_key_columns AS fc ON f.OBJECT_ID = fc.constraint_object_id
    WHERE g.LinkLevel < @MaxTablesBetween -- Add a filter to limit the number of intermediate tables.
),
TableLinks AS (
    SELECT 
        *,
        ROW_NUMBER() OVER (PARTITION BY ReferencingTable, ReferencingColumn, LinkLevel ORDER BY LinkLevel) AS RowNumber
    FROM ForeignKeyGraph
)
SELECT 
    ReferencingTable,
    ReferencingColumn,
    ForeignKeyName,
    ReferencedTable,
    ReferencedColumn,
    LinkLevel,
    LinkChain
FROM TableLinks
WHERE RowNumber = 1
    AND (
        (ReferencingTable = @SourceTable AND ReferencedTable = @TargetTable)
        OR
        (ReferencingTable = @TargetTable AND ReferencedTable = @SourceTable)
    )
ORDER BY LinkLevel;
