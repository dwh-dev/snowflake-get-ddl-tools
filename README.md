# Collection of Snowflake Scripting procedures extending [GET_DDL](https://docs.snowflake.com/en/sql-reference/functions/get_ddl.html) function by [dwh.dev](https://dwh.dev).


## Motivation
In [dwh.dev](https://dwh.dev) we build data lineage based on raw SQL queries. And the main source of truth for us is the result of GET_DDL function.
But GET_DDL function has a lot of issues:
  - alphabetical order instead of topological order of objects in schemas (we are fixed it in https://parsers.dev/tools/ddl/reordering)
  - you will never know about CTAS as CLONE
  - <del>commented semicolons between statements when the statement is finished with a comment</del> **fixed!**
  - some objects don't export (i.e. STAGEs, INTEGRATIONs, etc)
  - some objects export broken in some cases (i.e. STREAMs)
  - some objects export without TAG option

We made this repo to fix some of them. Here you can find the following procedures:
- GET_DDL_STAGES
- GET_DDL_STREAMS
- TODO:GET_DDL_TASKS

## How it works
**Step 1:** collect data from SHOW and DESCRIBE commands and return it as a VARIANT object. (```CALL GET_<object>S```)<br/>
**Step 2:** render VARIANT object to SQL text. (```CALL GET_DDL_<object>S```)
<br/>
<br/>
PS: We hope that one day this repository will become irrelevant :)
<br/>
<br/>
# GET_DDL_STAGES
**Problems:** 
  - GET_DDL don't return CREATE STAGE statements

**Returns:** VARCHAR with [CREATE STAGE](https://docs.snowflake.com/en/sql-reference/sql/create-stage.html) statements.
<br/>
**Use:** ```CALL GET_DDL_STAGES();```

### Supported features:
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
<br/>
<br/>

# GET_DDL_STREAMS
**Problems:** 
  - GET_DDL returns CREATE STREAM statements without noting the database and schema for the object it is based on.
  - CREATE STREAM have no TAG option.

**Returns:** VARCHAR with [CREATE STREAM](https://docs.snowflake.com/en/sql-reference/sql/create-stream.html) and [ALTER STREAM](https://docs.snowflake.com/en/sql-reference/sql/alter-stream.html) statements.
<br/>
**Use:** ```CALL GET_DDL_STREAMS()```;

### Supported features:
- [x] NAME
- [x] COMMENT 
- [x] TAGS
- [x] MODE (APPEND_ONLY/INSERT_ONLY)
- [x] FULL NAME of base TABLE/VIEW
- [x] FULL NAME of base STAGE if short name is not ambiguous
- [ ] SHOW_INITIAL_ROWS (NOT SUPPORTED BY SNOWFLAKE)
- [ ] COPY GRANTS (NOT SUPPORTED BY SNOWFLAKE)
- [ ] AT | BEFORE (NOT SUPPORTED BY SNOWFLAKE)
<br/>
<br/>

# TODO:GET_DDL_TASKS
**Problems:** 
  - CREATE TASK have no TAG option.

**Returns:** VARCHAR with [ALTER TASK](https://docs.snowflake.com/en/sql-reference/sql/alter-task.html) statements.
<br/>
**Use:** ```CALL GET_DDL_TASKS()```;
