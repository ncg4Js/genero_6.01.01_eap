-- nw_common.4gl: connection and helpers shared by all Northwind programs

SCHEMA northwind

FUNCTION nw_connect()
    DEFINE l_user, l_pwd STRING

    LET l_user = fgl_getenv("NW_USER")
    LET l_pwd  = fgl_getenv("NW_PASSWORD")
    IF l_user IS NULL OR l_pwd IS NULL THEN
        DISPLAY "Set NW_USER and NW_PASSWORD before starting the program."
        EXIT PROGRAM 1
    END IF

    WHENEVER ERROR CONTINUE
    CONNECT TO "northwind" USER l_user USING l_pwd
    WHENEVER ERROR STOP
    IF sqlca.sqlcode < 0 THEN
        DISPLAY "Cannot connect to northwind: ", sqlca.sqlcode, " ", sqlerrmessage
        EXIT PROGRAM 1
    END IF

    -- session settings
    SET ISOLATION TO COMMITTED READ
END FUNCTION

FUNCTION nw_disconnect()
    DISCONNECT CURRENT
END FUNCTION

-- next value of one of the SEQ_NW_* sequences
FUNCTION nw_next_id(p_seqname)
    DEFINE p_seqname STRING
    DEFINE l_id INTEGER

    PREPARE p_nextid FROM "SELECT " || p_seqname || ".NEXTVAL FROM systables WHERE tabid = 1"
    EXECUTE p_nextid INTO l_id
    FREE p_nextid
    RETURN l_id
END FUNCTION

-- name and version of the database server, for the title bars
FUNCTION nw_server_label()
    DEFINE l_db      VARCHAR(30)
    DEFINE l_user    VARCHAR(30)
    DEFINE l_version VARCHAR(100)

    SQL
        SELECT DBINFO('dbname'), USER
          INTO $l_db, $l_user
          FROM systables
         WHERE tabid = 1
    END SQL

    PREPARE p_ver FROM "SELECT DBINFO('version', 'full') FROM systables WHERE tabid = 1"
    EXECUTE p_ver INTO l_version
    FREE p_ver

    RETURN l_db CLIPPED || " (" || l_user CLIPPED || ") " || l_version CLIPPED
END FUNCTION

-- order total, as the reports and screens compute it
FUNCTION nw_line_total(p_price, p_qty, p_disc)
    DEFINE p_price  DECIMAL(10,2)
    DEFINE p_qty    INTEGER
    DEFINE p_disc   DECIMAL(4,2)

    RETURN p_price * p_qty * (1 - p_disc)
END FUNCTION

FUNCTION nw_message(p_text)
    DEFINE p_text STRING
    MESSAGE p_text
END FUNCTION

FUNCTION nw_info(p_title, p_text)
    DEFINE p_title, p_text STRING
    MENU p_title ATTRIBUTES(STYLE = "dialog", COMMENT = p_text, IMAGE = "information")
        COMMAND "OK"
            EXIT MENU
    END MENU
END FUNCTION
