-- Returns ARRAY of STREAM props objects
CREATE OR REPLACE PROCEDURE GET_STREAMS()
  RETURNS VARIANT
  LANGUAGE SQL
  EXECUTE AS CALLER
  AS $$
    DECLARE
        stream_variant_array VARIANT DEFAULT ARRAY_CONSTRUCT();
    BEGIN
          SHOW STREAMS;

          LET cur1 CURSOR FOR SELECT OBJECT_CONSTRUCT(*) AS OBJ FROM (
            SELECT
              "database_name" as CATALOG, "schema_name" AS SCHEMA, "name" AS NAME, "comment" AS COMMENT, "table_name" AS BASE_ON, UPPER("source_type") AS BASE_ON_TYPE,
              "mode" AS MODE
            FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()))
          );

          FOR row_variable IN cur1 DO
            LET catalog varchar := row_variable.OBJ:CATALOG;
            LET schema varchar :=  row_variable.OBJ:SCHEMA;
            LET name varchar := row_variable.OBJ:NAME;
            LET tags VARIANT := NULL;
            LET stream_variant VARIANT := NULL;

            SELECT ARRAY_AGG(o) INTO tags FROM (
                SELECT OBJECT_CONSTRUCT(*) o
                from (
                    SELECT '"'|| TAG_DATABASE || '"."'|| TAG_SCHEMA ||'"."'|| TAG_NAME ||'"' AS name, tag_value AS value
                    FROM TABLE(INFORMATION_SCHEMA.TAG_REFERENCES('"'|| :catalog || '"."'|| :schema ||'"."'|| :name ||'"', 'STREAM'))
                )
            );

            stream_variant := OBJECT_CONSTRUCT(
                'NAME', OBJECT_CONSTRUCT(
                    'CATALOG', catalog,
                    'SCHEMA', schema,
                    'NAME', name
                ),
                'COMMENT', row_variable.OBJ:COMMENT,
                'TAGS', tags,
                'OPTIONS', OBJECT_CONSTRUCT(
                    'MODE', row_variable.OBJ:MODE,
                    'BASED_ON', OBJECT_CONSTRUCT(
                        'NAME', row_variable.OBJ:BASE_ON,
                        'TYPE',  row_variable.OBJ:BASE_ON_TYPE
                    )
                )
              );
              stream_variant_array := ARRAY_APPEND(stream_variant_array, stream_variant);
           END FOR;
        RETURN stream_variant_array;
    END;
$$;

-- Returns VARCHAR with CREATE STREAM (https://docs.snowflake.com/en/sql-reference/sql/create-stream.html) and ALTER STREAM (https://docs.snowflake.com/en/sql-reference/sql/alter-stream.html) statements.
CREATE OR REPLACE PROCEDURE GET_DDL_STREAMS()
  RETURNS VARCHAR
  LANGUAGE SQL
  EXECUTE AS CALLER
  AS
$$
DECLARE
    result VARCHAR DEFAULT '';
BEGIN
    CALL GET_STREAMS();
    LET cur1 CURSOR FOR SELECT f.value as value FROM TABLE(RESULT_SCAN(LAST_QUERY_ID())) t, LATERAL FLATTEN(input =>t.$1) f;
    FOR row1 IN cur1 DO
        LET stream_name VARCHAR := '"' || row1.value:NAME:CATALOG || '"."' || row1.value:NAME:SCHEMA || '"."' || row1.value:NAME:NAME || '"';
        LET base_on_type VARCHAR := row1.value:OPTIONS:BASED_ON:TYPE;
        LET base_on_name VARCHAR := row1.value:OPTIONS:BASED_ON:NAME;

        result := result || 'CREATE OR REPLACE STREAM ' || stream_name;

        // fix for STAGE
        IF(base_on_type = 'STAGE') THEN
            CREATE OR REPLACE TEMP TABLE stagenames (name VARIANT);
            CALL GET_STAGES();
            INSERT INTO stagenames
                SELECT f.value:NAME FROM TABLE(RESULT_SCAN(LAST_QUERY_ID())) t, LATERAL FLATTEN(input =>t.$1) f
                    WHERE f.value:NAME:NAME = :base_on_name AND f.value:OPTIONS:DIRECTORY:ENABLE:VALUE = 'true';

            IF((SELECT COUNT(*) FROM stagenames) = 1) THEN
                LET stage_name VARIANT := (SELECT name FROM stagenames);
                result := result || ' ON STAGE "'|| :stage_name:CATALOG || '"."' || :stage_name:SCHEMA || '"."' || :stage_name:NAME || '"';
            ELSE
                result := result || ' ON STAGE ' || row1.value:OPTIONS:BASED_ON:NAME || ' /* cant parse full stage name - it is ambiguous!!! */';
            END IF;
        ELSE
            result := result || ' ON ' || row1.value:OPTIONS:BASED_ON:TYPE || ' ' || row1.value:OPTIONS:BASED_ON:NAME;
        END IF;

        IF (row1.value:OPTIONS:MODE != 'DEFAULT') THEN
            result := result || ' ' || row1.value:OPTIONS:MODE || ' = TRUE';
        END IF;

        -- COMMENT
        IF (row1.value:COMMENT != '' ) THEN
            result := result || ' COMMENT = \'' || row1.value:COMMENT || '\'';
        END IF;

        -- TAGS
        LET tags_count INTEGER := ARRAY_SIZE(row1.value:TAGS);
        IF (tags_count > 0) THEN
            result := result || '; ALTER STREAM ' || stream_name || ' SET TAG ';
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