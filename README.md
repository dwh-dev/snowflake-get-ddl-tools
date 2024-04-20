# Collection of Snowflake Scripting procedures extending [GET_DDL](https://docs.snowflake.com/en/sql-reference/functions/get_ddl.html) function by [dwh.dev](https://dwh.dev).


## Motivation
In [dwh.dev](https://dwh.dev) we build data lineage based on raw SQL queries. And the main source of truth for us is the result of GET_DDL function.
But GET_DDL function has a lot of issues:
  - alphabetical order instead of topological order of objects in schemas (we are fixed it in https://parsers.dev/tools/ddl/reordering)
  - you will never know about CTAS and CLONE
  - <del>commented semicolons between statements when the statement is finished with a comment</del> **fixed by Snowflake!**
  - some objects don't export (i.e. STAGEs, INTEGRATIONs, etc)
  - some objects export broken in some cases (i.e. STREAMs)
  - some objects export without TAG option

We made this repo to fix some of them. Here you can find the following procedures:
- **GET_DDL_STAGES**
- **GET_DDL_STREAMS**
- **GET_DDL_TASKS**
- **GET_DDL_PIPES**
- **GET_DDL_TAGS**
- **GET_DDL_POLICIES**
- **GET_DDL_PROCEDURES**

## How it works
**Step 1:** collect data from SHOW and DESCRIBE commands and return it as a VARIANT object. (```CALL GET_<object>S```)

**Step 2:** render VARIANT object to SQL text. (```CALL GET_DDL_<object>S```)

PS: We hope that one day this repository will become irrelevant :)

# **GET_DDL_STAGES**
**Problems:** 
  - GET_DDL don't return **CREATE STAGE** statements

**Returns:** VARCHAR with [CREATE STAGE](https://docs.snowflake.com/en/sql-reference/sql/create-stage.html) statements.

**Use:** ```CALL GET_DDL_STAGES();```

### Supported features:
- [x] NAME
- [x] COMMENT 
- [x] TAGS
- [x] URL (STAGE_LOCATION)
- [ ] OPTIONS:
  - [ ] DIRECTORY
    - [ ] ENABLE
    - [ ] AUTO_REFRESH
  - [ ] STORAGE_INTEGRATION
  - [ ] CREDENTIALS (STAGE_CREDENTIALS)
      - [ ] AWS_KEY_ID
  - [ ] ENCRYPTION
  - [ ] FILE_FORMAT (STAGE_FILE_FORMAT)
    - [ ] formatTypeOptions
  - [ ] COPY_OPTIONS (STAGE_COPY_OPTIONS)
    - [ ] ENFORCE_LENGTH
    - [ ] FORCE
    - [ ] ON_ERROR
    - [ ] PURGE
    - [ ] RETURN_FAILED_ONLY
    - [ ] SIZE_LIMIT
    - [ ] TRUNCATECOLUMNS

# **GET_DDL_STREAMS**
**Problems:** 
  - GET_DDL returns **CREATE STREAM** statements without noting the database and schema for the object it is based on.

**Returns:** VARCHAR with [CREATE STREAM](https://docs.snowflake.com/en/sql-reference/sql/create-stream.html) and [ALTER STREAM](https://docs.snowflake.com/en/sql-reference/sql/alter-stream.html) statements (for tags).

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


# **GET_DDL_TASKS**
**Problems:** 
  - **CREATE TASK** have no TAG option.

**Returns:** VARCHAR with [ALTER TASK](https://docs.snowflake.com/en/sql-reference/sql/alter-task.html) statements.

**Use:** ```CALL GET_DDL_TASKS()```;

# **GET_DDL_PIPES**
**Problems:** 
  - <del>**GET_DDL** returns **CREATE PIPE** only one by one. You should call it for each pipe in your account.</del> **fixed by Snowflake!** 
  - The same problem with **GRANT**.

**Returns:** VARCHAR with [CREATE PIPE](https://docs.snowflake.com/en/sql-reference/sql/create-pipe.html) (with tags).

**Use:** ```CALL GET_DDL_PIPES();```

### Supported features:
- [x] NAME
- [x] COMMENT 
- [x] TAGS
- [x] AUTO_INGEST
- [x] INTEGRATION
- [x] ERROR_INTEGRATION
- [ ] AWS_SNS_TOPIC (NOT SUPPORTED BY SNOWFLAKE)


# **GET_DDL_TAGS**
**Problems:** 
  - **CREATE TAG** have no MASKING POLICY option.

**Returns:** VARCHAR with [ALTER TAG](https://docs.snowflake.com/en/sql-reference/sql/alter-tag) statements.

**Use:** ```CALL GET_DDL_TAGS()```;



# TODO: **GET_DDL_POLICIES**
**Problems:** 
  - **CREATE NETWORK/PASSWORD/SESSION/ROW ACCESS/MASKING POLICY** have no TAG option.

**Returns:** VARCHAR with ALTER _ POLICY statements.

**Use:** ```CALL GET_DDL_POLICIES()```;

# TODO: **GET_DDL_PROCEDURES**
**Problems:** 
  - **CREATE PROCEDURE** have no TAG option.

**Returns:** VARCHAR with ALTER PROCEDURE statements.

**Use:** ```CALL GET_DDL_PROCEDURES()```;