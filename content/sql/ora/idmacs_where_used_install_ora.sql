-- Copyright (c) 2014, Lambert Boskamp
-- All rights reserved.

-- Redistribution and use in source and binary forms, with or without
-- modification, are permitted provided that the following conditions
-- are met:

-- 1. Redistributions of source code must retain the above copyright
-- notice, this list of conditions and the following disclaimer.

-- 2. Redistributions in binary form must reproduce the above 
-- copyright notice, this list of conditions and the following
-- disclaimer in the documentation and/or other materials provided
-- with the distribution.

-- THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
-- "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT 
-- LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS 
-- FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE 
-- COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, 
-- INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
-- (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
-- SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
-- HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
-- STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) 
-- ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED
-- OF THE POSSIBILITY OF SUCH DAMAGE.
--
-- *******************************************************************
-- TODO:
-- * Documentation
-- *******************************************************************

--------------------------------------------------------
--  DDL for Type IDMACS_CLOB_OBJ
--------------------------------------------------------
  DROP PACKAGE BODY "IDMACS_WHERE_USED";
  DROP PACKAGE "IDMACS_WHERE_USED";
  DROP TYPE "IDMACS_CLOB_TAB";
  DROP TYPE BODY "IDMACS_CLOB_OBJ";
  DROP TYPE "IDMACS_CLOB_OBJ";
  
  CREATE OR REPLACE TYPE "IDMACS_CLOB_OBJ" 
    as object (
  
    node_id          NUMBER(10,0)
    ,node_name       varchar2(2000)
    ,node_data       clob

    ,constructor function idmacs_clob_obj
    RETURN self AS result
  
    ,constructor function idmacs_clob_obj(iv_dbms_sql_cursor in integer)
    return self as result

  ,member procedure define_columns(iv_dbms_sql_cursor in integer)
);
/
CREATE OR REPLACE TYPE BODY "IDMACS_CLOB_OBJ" 
    as
  /**
   * Constructor. Sets all attributes to NULL.
   * @return  New object type instance.
   */
  constructor function idmacs_clob_obj
  return self as result as

  begin
    RETURN;
  end idmacs_clob_obj;

  /**
   * Constructs a new instance with values fetched from DBMS_SQL cursor
   *
   * @param   iv_dbms_sql_cursor
   * @return  new object type instance
   */
  constructor function idmacs_clob_obj(iv_dbms_sql_cursor in integer)
  return self as result
  as
    lv_long_val long;
    lv_long_len integer;
    lv_buf_len  integer := 32760;
    lv_cur_pos  number := 0;
  begin
      dbms_sql.column_value(iv_dbms_sql_cursor, 01, node_id);
      dbms_sql.column_value(iv_dbms_sql_cursor, 02, node_name);

      -- Create CLOB.
      dbms_lob.createtemporary(node_data, false, dbms_lob.call);

      -- Piecewise fetching of the LONG column, appending to the CLOB
      loop
          dbms_sql.column_value_long(
              iv_dbms_sql_cursor,
              ,03 --column ID of LONG column
              ,lv_buf_len
              ,lv_cur_pos
              ,lv_long_val
              ,lv_long_len
          );
          exit when lv_long_len = 0;

	  dbms_lob.append(node_data, lv_long_val);
          lv_cur_pos := lv_cur_pos + lv_long_len;
      end loop;

    RETURN;
  end idmacs_clob_obj;

  /**
   * Defines all columns in DBMS_SQL cursor
   * @param  iv_dbms_sql_cursor parsed DBMS_SQL cursor
   */
  member procedure define_columns(iv_dbms_sql_cursor in integer) 
  as

  BEGIN
     -- INT column
    dbms_sql.define_column(iv_dbms_sql_cursor, 01, node_id);
    -- VARCHAR2 column
    dbms_sql.define_column(iv_dbms_sql_cursor, 02, node_name, 90);
    -- LONG column
    dbms_sql.define_column_long(iv_dbms_sql_cursor, 03);
  end define_columns;
END;
/
--------------------------------------------------------
--  DDL for Type IDMACS_CLOB_TAB
--------------------------------------------------------

  CREATE OR REPLACE TYPE "IDMACS_CLOB_TAB" 
    AS
    TABLE OF idmacs_clob_obj;
/
--------------------------------------------------------
--  DDL for Package IDMACS_WHERE_USED
--------------------------------------------------------

  CREATE OR REPLACE PACKAGE "IDMACS_WHERE_USED" 
    AUTHID CURRENT_USER
    AS 
  
    FUNCTION BASE64_DECODE(
        iv_base64 IN CLOB
    )
    RETURN CLOB;
    
    FUNCTION READ_TAB_WITH_LONG_COL_PTF(
        iv_table_name        IN VARCHAR2
        ,iv_id_column_name   IN VARCHAR2
        ,iv_name_column_name IN VARCHAR2
        ,iv_long_column_name IN VARCHAR2
    )
    RETURN idmacs_clob_tab PIPELINED;
    
END IDMACS_WHERE_USED;
/

--------------------------------------------------------
--  DDL for Package Body IDMACS_WHERE_USED
--------------------------------------------------------

  CREATE OR REPLACE PACKAGE BODY "IDMACS_WHERE_USED" 
    AS

  FUNCTION BASE64_DECODE(
        iv_base64 IN CLOB
    )
    RETURN CLOB AS
      lv_result               CLOB;
      lv_substring            VARCHAR2(2000);
      lv_num_chars_to_read    PLS_INTEGER := 0;
      lv_offset               PLS_INTEGER := 1;
      lv_num_chars_remaining  PLS_INTEGER := 0;
  BEGIN
      lv_num_chars_remaining := LENGTH(iv_base64) - lv_offset;
     
      WHILE lv_num_chars_remaining > 0 LOOP
     
      lv_num_chars_to_read := LEAST(lv_num_chars_remaining, 2000);
     
      lv_substring := DBMS_LOB.SUBSTR(
          iv_base64
          ,lv_num_chars_to_read
          ,lv_offset);
     
      lv_offset := lv_offset + lv_num_chars_to_read;
     
      lv_num_chars_remaining
          := lv_num_chars_remaining - lv_num_chars_to_read;
                                     
        lv_result
          := lv_result
          || UTL_RAW.cast_to_varchar2(
              UTL_ENCODE.base64_decode(
                UTL_RAW.cast_to_raw(lv_substring)));
      END LOOP;
     
      RETURN lv_result;
  
  END BASE64_DECODE; 
  
function READ_TAB_WITH_LONG_COL_PTF(
        iv_table_name        in varchar2
        ,iv_id_column_name   in varchar2
        ,iv_name_column_name in varchar2
        ,iv_long_column_name in varchar2
    )
    return idmacs_clob_tab pipelined
as
  lv_query           varchar2(200);
  lv_dbms_sql_cursor binary_integer;
  lv_execute_rc      pls_integer;
  lo_clob_object     idmacs_clob_obj;

-- TODO: Validation of input arguments to avoid SQL injection
begin
  -- TODO: don't enable SERVEROUTPUT in code; let users do it
  dbms_output.enable(buffer_size => 1000000);
  
  lv_query :=
     'select '
     || iv_id_column_name
     || ', '
     || iv_name_column_name
     || ', ' 
     || iv_long_column_name
     || ' from '
     || iv_table_name
     ;

  -- Create cursor, parse and bind
  lv_dbms_sql_cursor := dbms_sql.open_cursor;
  dbms_output.put_line('Open cursor succeeded');
  
  dbms_sql.parse(lv_dbms_sql_cursor, lv_query, dbms_sql.NATIVE);
  dbms_output.put_line('Parse cursor succeeded');
  
  -- Define columns through dummy object type instance
  lo_clob_object := idmacs_clob_obj();
  dbms_output.put_line('lo_clob_object initialized');
  
  lo_clob_object.define_columns(lv_dbms_sql_cursor);
  dbms_output.put_line('Define columns succeeded');
  
  -- Execute
  lv_execute_rc := dbms_sql.execute(lv_dbms_sql_cursor);
  dbms_output.put_line('Cursor executed, RC='||lv_execute_rc);
  
  -- Fetch all rows, pipe each back
  while dbms_sql.fetch_rows(lv_dbms_sql_cursor) > 0 loop
  
    lo_clob_object := idmacs_clob_obj(lv_dbms_sql_cursor);
    dbms_output.put_line('lo_clob_object populated');
    
    pipe row(lo_clob_object);
    dbms_output.put_line('Current row piped back to caller');
  end loop;

  dbms_sql.close_cursor(lv_dbms_sql_cursor);
exception
  when others then
    
    dbms_output.put_line('SQLERRM:    ' || sqlerrm);
    dbms_output.put_line('CALLSTACK:  ' || dbms_utility.format_call_stack);
    dbms_output.put_line('ERRORSTACK: ' || dbms_utility.format_error_stack);
    dbms_output.put_line('BACKTRACE:  ' || dbms_utility.format_error_backtrace);
    
    if dbms_sql.is_open(lv_dbms_sql_cursor) then
      dbms_sql.close_cursor(lv_dbms_sql_cursor);
    end if;

    raise;
end READ_TAB_WITH_LONG_COL_PTF;

END IDMACS_WHERE_USED;
/
