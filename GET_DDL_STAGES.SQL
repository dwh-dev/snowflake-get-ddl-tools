-- Returns ARRAY of STAGE props objects
CREATE OR REPLACE PROCEDURE GET_STAGES(DBNAME STRING DEFAULT NULL)
  RETURNS VARIANT
  LANGUAGE SQL
  EXECUTE AS CALLER
  AS $$
    DECLARE
        desc_result VARIANT;
        stage_variant VARIANT;
        stage_variant_array VARIANT DEFAULT ARRAY_CONSTRUCT();
    BEGIN
        LET DBFILTER STRING := '';
        IF (DBNAME IS NOT NULL) THEN
            DBFILTER := ' AND STAGE_CATALOG = ''' || :DBNAME || '''';
        END IF;

        EXECUTE IMMEDIATE 'SELECT
                STAGE_CATALOG,
                STAGE_SCHEMA,
                STAGE_NAME 
            FROM INFORMATION_SCHEMA.STAGES
            WHERE STAGE_TYPE IS NOT NULL ' || DBFILTER || ' ORDER BY 1,2,3'
        ;
        
        LET cur1 CURSOR FOR SELECT * FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()));
        FOR row_variable IN cur1 DO
            LET catalog varchar := row_variable.STAGE_CATALOG;
            LET schema varchar := row_variable.STAGE_SCHEMA;
            LET name varchar := row_variable.STAGE_NAME;
            LET comment VARCHAR := NULL;
            LET tags VARIANT := NULL;


            EXECUTE IMMEDIATE 'DESC STAGE "' || catalog || '"."' || schema || '"."' || name || '"';

            desc_result :=
            ( 
                SELECT
                    OBJECT_AGG(K, V)
                FROM (
                    SELECT
                        OBJ['PARENT'] as K,
                        OBJECT_AGG
                        (
                            OBJ['KEY']::VARCHAR, OBJECT_CONSTRUCT
                            (
                                'TYPE', OBJ['TYPE'],
                                'VALUE', OBJ['VALUE'],
                                'IS_DEFAULT', OBJ['IS_DEFAULT']
                            )
                        ) AS V
                    FROM (
                        SELECT
                            OBJECT_CONSTRUCT(*) AS OBJ
                        FROM (
                            SELECT
                                "parent_property"                     AS PARENT,
                                "property"                            AS KEY,
                                "property_type"                       AS TYPE,
                                "property_value"                      AS VALUE,
                                "property_value" = "property_default" AS IS_DEFAULT
                            FROM TABLE (RESULT_SCAN(LAST_QUERY_ID()))
                        )
                    )
                    GROUP BY 1
                )
            );

            SHOW STAGES;
            SELECT "comment" INTO :comment
                FROM TABLE(RESULT_SCAN(LAST_QUERY_ID())) t
                WHERE
                        t."database_name" = :catalog
                        AND t."schema_name" = :schema
                        AND t."name" = :name
            ;
            SELECT ARRAY_AGG(o) INTO tags FROM (
                SELECT OBJECT_CONSTRUCT(*) o
                from (
                    SELECT '"'|| TAG_DATABASE || '"."'|| TAG_SCHEMA ||'"."'|| TAG_NAME ||'"' AS name, tag_value AS value
                    FROM TABLE(INFORMATION_SCHEMA.TAG_REFERENCES('"'|| :catalog || '"."'|| :schema ||'"."'|| :name ||'"', 'STAGE'))
                )
            );
            stage_variant := OBJECT_CONSTRUCT(
                'NAME', OBJECT_CONSTRUCT(
                    'CATALOG', catalog,
                    'SCHEMA', schema,
                    'NAME', name
                ),
                'COMMENT', comment,
                'TAGS', tags,
                'OPTIONS', desc_result
            );
            stage_variant_array := ARRAY_APPEND(stage_variant_array, stage_variant);
        END FOR;
        RETURN stage_variant_array;
    END;
$$;

-- Returns VARCHAR with CREATE STAGE (https://docs.snowflake.com/en/sql-reference/sql/create-stage.html) statements.
-- TODO: respect all props
CREATE OR REPLACE PROCEDURE GET_DDL_STAGES(DBNAME STRING DEFAULT NULL)
  RETURNS VARCHAR
  LANGUAGE SQL
  EXECUTE AS CALLER
  AS
$$
DECLARE
    result VARCHAR DEFAULT '';
    url VARCHAR DEFAULT '';
BEGIN
    CALL GET_STAGES(:DBNAME);
    LET cur1 CURSOR FOR
        SELECT f.value as value 
        FROM
            TABLE(RESULT_SCAN(LAST_QUERY_ID())) t,
            LATERAL FLATTEN(input =>t.$1) f
    ;
    FOR row1 IN cur1 DO
        LET stage_name VARCHAR := '"' || row1.value:NAME:CATALOG || '"."' || row1.value:NAME:SCHEMA || '"."' || row1.value:NAME:NAME || '"';

        result := result || 'CREATE OR REPLACE STAGE ' || stage_name;

        IF (row1.value:OPTIONS:STAGE_LOCATION:URL:VALUE != '' ) THEN
            url := PARSE_JSON(row1.value:OPTIONS:STAGE_LOCATION:URL:VALUE)[0]::TEXT;
            result := result || ' URL = \'' || url || '\'';
        END IF;

        -- COMMENT
        IF (row1.value:COMMENT != '' ) THEN
            result := result || ' COMMENT = \'' || row1.value:COMMENT || '\'';
        END IF;

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

        result := result || ';\n';
    END FOR;

    RETURN result;
END;
$$;