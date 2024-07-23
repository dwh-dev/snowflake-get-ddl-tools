-- Returns ARRAY of TAG props objects
CREATE OR REPLACE PROCEDURE GET_MASKING_POLICIES(DBNAME STRING DEFAULT NULL)
  RETURNS VARIANT
  LANGUAGE SQL
  EXECUTE AS CALLER
  AS $$
    DECLARE
        masking_policies_array VARIANT DEFAULT ARRAY_CONSTRUCT();
    BEGIN
         IF (DBNAME IS NULL) THEN
            SHOW MASKING POLICIES;
        ELSE
            EXECUTE IMMEDIATE 'SHOW MASKING POLICIES IN DATABASE '||:DBNAME;
        END IF;

        LET cur1 CURSOR FOR SELECT OBJECT_CONSTRUCT(*) AS OBJ FROM (
        SELECT
            "database_name" as CATALOG,
            "schema_name" AS SCHEMA,
            "name" AS NAME,
            "comment" AS COMMENT,
            "options" AS OPTIONS
        FROM
            TABLE(RESULT_SCAN(LAST_QUERY_ID()))
        );

        FOR row_variable IN cur1 DO
            LET catalog varchar := row_variable.OBJ:CATALOG;
            LET schema varchar :=  row_variable.OBJ:SCHEMA;
            LET name varchar := row_variable.OBJ:NAME;
            LET mp_variant VARIANT := NULL;

            mp_variant := OBJECT_CONSTRUCT(
                'NAME', OBJECT_CONSTRUCT(
                    'CATALOG', catalog,
                    'SCHEMA', schema,
                    'NAME', name
                ),
                'COMMENT', row_variable.OBJ:COMMENT,
                'OPTIONS', row_variable.OPTIONS
            );
            masking_policies_array := ARRAY_APPEND(masking_policies_array, mp_variant);
           END FOR;
        RETURN masking_policies_array;
    END;
$$;


-- Returns VARCHAR with ALTER TAG (https://docs.snowflake.com/en/sql-reference/sql/alter-tag) statements.
CREATE OR REPLACE PROCEDURE GET_DDL_TAGS(DBNAME STRING DEFAULT NULL)
  RETURNS VARCHAR
  LANGUAGE SQL
  EXECUTE AS CALLER
  AS
$$
DECLARE
    result VARCHAR DEFAULT '';
BEGIN
    CALL GET_MASKING_POLICIES(:DBNAME);
    LET cur1 CURSOR FOR SELECT f.value as value FROM TABLE(RESULT_SCAN(LAST_QUERY_ID())) t, LATERAL FLATTEN(input =>t.$1) f;
    FOR row1 IN cur1 DO
      LET mp_name VARCHAR := row1.value:NAME:CATALOG || '.' || row1.value:NAME:SCHEMA || '.' || row1.value:NAME:NAME ;

      LET sql_stmt := 'SELECT REF_DATABASE_NAME, REF_SCHEMA_NAME, REF_ENTITY_NAME FROM TABLE(information_schema.policy_references(policy_name => \'' || mp_name || '\')) WHERE REF_ENTITY_DOMAIN = \'TAG\' AND POLICY_STATUS = \'ACTIVE\';';
      EXECUTE IMMEDIATE :sql_stmt;

      LET cur2 CURSOR FOR SELECT * FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()));
      FOR row2 IN cur2 DO
        LET tag_name VARCHAR := '"' || row2.REF_DATABASE_NAME || '"."' || row2.REF_SCHEMA_NAME || '"."' || row2.REF_ENTITY_NAME || '"';
        result := result || 'ALTER TAG ' || tag_name || ' SET MASKING POLICY ' || mp_name || ';\n';
      END FOR;
    END FOR;

    RETURN result;
END;
$$;