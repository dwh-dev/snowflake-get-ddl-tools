# Collection of Snowflake Scripting procedures extending [GET_DDL](https://docs.snowflake.com/en/sql-reference/functions/get_ddl.html) function.


## GET_DDL_STAGES
**Returns:** VARCHAR with [CREATE STAGE](https://docs.snowflake.com/en/sql-reference/sql/create-stage.html) statements.

**Use:** CALL GET_DDL_STAGES();

### Respect:
- [x] NAME
- [x] COMMENT 
- [x] TAGS
- [ ] URL
- [ ] STORAGE_INTEGRATION
- [ ] CREDENTIALS
- [ ] ENCRYPTION
- [ ] DIRECTORY
- [ ] FILE_FORMAT
  - [ ] formatTypeOptions
- [ ] COPY_OPTIONS
