-- Returns ARRAY of PIPE props objects
CREATE OR REPLACE PROCEDURE GET_PIPES()
  RETURNS VARIANT
  LANGUAGE SQL
  EXECUTE AS CALLER
  AS $$
    DECLARE
        pipe_variant_array VARIANT DEFAULT ARRAY_CONSTRUCT();
    BEGIN
        SHOW PIPES;

        LET cur1 CURSOR FOR SELECT OBJECT_CONSTRUCT(*) AS OBJ FROM (
        SELECT
            "database_name" as CATALOG,
            "schema_name" AS SCHEMA,
            "name" AS NAME,
            "comment" AS COMMENT,
            "definition" AS DEFINITION,
            "notification_channel" AS NOTIFICATION_CHANNEL,
            "integration" AS INTEGRATION,
            "pattern" AS PATTERN,
            "error_integration" AS ERROR_INTEGRATION,
            CASE IS_AUTOINGEST_ENABLED
            WHEN 'NO' THEN FALSE
            ELSE TRUE
            END AS AUTO_INGEST
        FROM
            TABLE(RESULT_SCAN(LAST_QUERY_ID())) s,
            INFORMATION_SCHEMA.PIPES p
        WHERE
            p.PIPE_CATALOG = s."database_name" 
            AND p.PIPE_SCHEMA = s."schema_name" 
            AND p.PIPE_NAME = s."name"

        );

        FOR row_variable IN cur1 DO
            LET catalog varchar := row_variable.OBJ:CATALOG;
            LET schema varchar :=  row_variable.OBJ:SCHEMA;
            LET name varchar := row_variable.OBJ:NAME;
            LET tags VARIANT := NULL;
            LET pipe_variant VARIANT := NULL;

            SELECT ARRAY_AGG(o) INTO tags FROM (
                SELECT OBJECT_CONSTRUCT(*) o
                from (
                    SELECT '"'|| TAG_DATABASE || '"."'|| TAG_SCHEMA ||'"."'|| TAG_NAME ||'"' AS name, tag_value AS value
                    FROM TABLE(INFORMATION_SCHEMA.TAG_REFERENCES('"'|| :catalog || '"."'|| :schema ||'"."'|| :name ||'"', 'PIPE'))
                )
            );

            pipe_variant := OBJECT_CONSTRUCT(
                'NAME', OBJECT_CONSTRUCT(
                    'CATALOG', catalog,
                    'SCHEMA', schema,
                    'NAME', name
                ),
                'COMMENT', row_variable.OBJ:COMMENT,
                'TAGS', tags,
                'OPTIONS', OBJECT_CONSTRUCT(
                    'DEFINITION', row_variable.OBJ:DEFINITION,
                    'NOTIFICATION_CHANNEL', row_variable.OBJ:NOTIFICATION_CHANNEL,
                    'INTEGRATION', row_variable.OBJ:INTEGRATION,
                    'PATTERN', row_variable.OBJ:PATTERN,
                    'ERROR_INTEGRATION', row_variable.OBJ:ERROR_INTEGRATION,
                    'AUTO_INGEST', row_variable.OBJ:AUTO_INGEST
                )
                );
            pipe_variant_array := ARRAY_APPEND(pipe_variant_array, pipe_variant);
        END FOR;
        RETURN pipe_variant_array;
    END;
$$;


-- Returns VARCHAR with CREATE PIPE (https://docs.snowflake.com/en/sql-reference/sql/create-pipe.html) and ALTER PIPE (https://docs.snowflake.com/en/sql-reference/sql/alter-pipe.html) statements.
CREATE OR REPLACE PROCEDURE GET_DDL_PIPES()
  RETURNS VARCHAR
  LANGUAGE SQL
  EXECUTE AS CALLER
  AS
$$
DECLARE
    result VARCHAR DEFAULT '';
BEGIN
    CALL GET_PIPES();
    LET cur1 CURSOR FOR 
        SELECT f.value as value 
        FROM 
            TABLE(RESULT_SCAN(LAST_QUERY_ID())) t,
            LATERAL FLATTEN(input =>t.$1) f
    ;

    FOR row1 IN cur1 DO
        LET pipe_name VARCHAR := '"' || row1.value:NAME:CATALOG || '"."' || row1.value:NAME:SCHEMA || '"."' || row1.value:NAME:NAME || '"';

        result := result || 'CREATE OR REPLACE PIPE ' || pipe_name;

        -- TAGS
        LET tags_count INTEGER := ARRAY_SIZE(row1.value:TAGS);
        IF (tags_count > 0) THEN
            result := result || ' WITH TAG (';
            LET tags_array VARIANT := ARRAY_CONSTRUCT();
            FOR i IN 0 TO tags_count - 1 DO
                tags_array := ARRAY_APPEND(tags_array, row1.value:TAGS[i]:NAME || ' = \''|| row1.value:TAGS[i]:VALUE || '\'');
            END FOR;
            result := result ||  ARRAY_TO_STRING(tags_array, ', ') || ')';
        END IF;

        IF (row1.value:OPTIONS:AUTO_INGEST IS NOT NULL) THEN
            result := result || ' AUTO_INGEST = ' || row1.value:OPTIONS:AUTO_INGEST;
        END IF;

        IF (row1.value:OPTIONS:ERROR_INTEGRATION IS NOT NULL) THEN
            result := result || ' ERROR_INTEGRATION = ' || row1.value:OPTIONS:ERROR_INTEGRATION;
        END IF;

        IF (row1.value:OPTIONS:INTEGRATION IS NOT NULL) THEN
            result := result || ' INTEGRATION = ' || row1.value:OPTIONS:INTEGRATION;
        END IF;

        -- COMMENT
        IF (row1.value:COMMENT != '' ) THEN
            result := result || ' COMMENT = \'' || row1.value:COMMENT || '\'';
        END IF;

        result := result || ' AS ' || row1.value:OPTIONS:DEFINITION;

         -- TAGS
        LET tags_count INTEGER := ARRAY_SIZE(row1.value:TAGS);
        IF (tags_count > 0) THEN
            result := result || '; ALTER PIPE ' || pipe_name || ' SET TAG ';
            LET tags_array VARIANT := ARRAY_CONSTRUCT();
            FOR i IN 0 TO tags_count - 1 DO
                tags_array := ARRAY_APPEND(tags_array, row1.value:TAGS[i]:NAME || ' = \''|| row1.value:TAGS[i]:VALUE || '\'');
            END FOR;
            result := result ||  ARRAY_TO_STRING(tags_array, ', ');
        END IF;

        result := result || ';\n';
    END FOR;

    RETURN result;
END;
$$;