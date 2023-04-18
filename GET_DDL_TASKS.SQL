-- Returns ARRAY of TASK props objects
CREATE OR REPLACE PROCEDURE GET_TASKS()
  RETURNS VARIANT
  LANGUAGE SQL
  EXECUTE AS CALLER
  AS $$
    DECLARE
        task_variant_array VARIANT DEFAULT ARRAY_CONSTRUCT();
    BEGIN
          SHOW TASKS;

          LET cur1 CURSOR FOR SELECT OBJECT_CONSTRUCT(*) AS OBJ FROM (
            SELECT
              "database_name" as CATALOG, "schema_name" AS SCHEMA, "name" AS NAME, "comment" AS COMMENT, 
              "warehouse" AS WAREHOUSE, 
              "schedule" AS SCHEDULE, 
              "predecessors" AS PREDECESSORS, 
              "state" AS STATE,
              "definition" AS DEFINITION, 
              "condition" AS CONDITION, 
              "allow_overlapping_execution" AS ALLOW_OVERLAP,
              "error_integration" AS ERROR_INTEGRATION
            FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()))
          );

          FOR row_variable IN cur1 DO
            LET catalog varchar := row_variable.OBJ:CATALOG;
            LET schema varchar :=  row_variable.OBJ:SCHEMA;
            LET name varchar := row_variable.OBJ:NAME;
            LET tags VARIANT := NULL;
            LET task_variant VARIANT := NULL;

            SELECT ARRAY_AGG(o) INTO tags FROM (
                SELECT OBJECT_CONSTRUCT(*) o
                from (
                    SELECT '"'|| TAG_DATABASE || '"."'|| TAG_SCHEMA ||'"."'|| TAG_NAME ||'"' AS name, tag_value AS value
                    FROM TABLE(INFORMATION_SCHEMA.TAG_REFERENCES('"'|| :catalog || '"."'|| :schema ||'"."'|| :name ||'"', 'TASK'))
                )
            );

            task_variant := OBJECT_CONSTRUCT(
                'NAME', OBJECT_CONSTRUCT(
                    'CATALOG', catalog,
                    'SCHEMA', schema,
                    'NAME', name
                ),
                'COMMENT', row_variable.OBJ:COMMENT,
                'TAGS', tags,
                'OPTIONS', OBJECT_CONSTRUCT(
                    'WAREHOUSE', row_variable.OBJ:WAREHOUSE,
                    'SCHEDULE', row_variable.OBJ:SCHEDULE,
                    'PREDECESSORS', row_variable.OBJ:PREDECESSORS,
                    'STATE', row_variable.OBJ:STATE,
                    'DEFINITION', row_variable.OBJ:DEFINITION,
                    'CONDITION', row_variable.OBJ:CONDITION,
                    'ALLOW_OVERLAP', row_variable.OBJ:ALLOW_OVERLAP,
                    'ERROR_INTEGRATION', row_variable.OBJ:ERROR_INTEGRATION
                )
              );
              task_variant_array := ARRAY_APPEND(task_variant_array, task_variant);
           END FOR;
        RETURN task_variant_array;
    END;
$$;


-- Returns VARCHAR with CREATE TASK (https://docs.snowflake.com/en/sql-reference/sql/create-task.html) and ALTER TASK (https://docs.snowflake.com/en/sql-reference/sql/alter-task.html) statements.
CREATE OR REPLACE PROCEDURE GET_DDL_TASKS()
  RETURNS VARCHAR
  LANGUAGE SQL
  EXECUTE AS CALLER
  AS
$$
DECLARE
    result VARCHAR DEFAULT '';
BEGIN
    CALL GET_TASKS();
    LET cur1 CURSOR FOR SELECT f.value as value FROM TABLE(RESULT_SCAN(LAST_QUERY_ID())) t, LATERAL FLATTEN(input =>t.$1) f;
    FOR row1 IN cur1 DO
        LET task_name VARCHAR := '"' || row1.value:NAME:CATALOG || '"."' || row1.value:NAME:SCHEMA || '"."' || row1.value:NAME:NAME || '"';

        -- TAGS
        LET tags_count INTEGER := ARRAY_SIZE(row1.value:TAGS);
        IF (tags_count > 0) THEN
            result := result || 'ALTER TASK ' || task_name || ' SET TAG ';
            LET tags_array VARIANT := ARRAY_CONSTRUCT();
            FOR i IN 0 TO tags_count - 1 DO
                tags_array := ARRAY_APPEND(tags_array, row1.value:TAGS[i]:NAME || ' = \''|| row1.value:TAGS[i]:VALUE || '\'');
            END FOR;
            result := result ||  ARRAY_TO_STRING(tags_array, ', ') || ';\n';
        END IF;
    END FOR;

    RETURN result;
END;
$$;