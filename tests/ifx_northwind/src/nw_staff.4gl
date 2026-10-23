-- nw_staff.4gl: Northwind staff (management tree, sales per employee, territories)

SCHEMA northwind

DEFINE m_tree DYNAMIC ARRAY OF RECORD
    t_lvl        INTEGER,
    t_employeeid LIKE employees.employeeid,
    t_fullname   VARCHAR(60),
    t_title      LIKE employees.title,
    t_path       VARCHAR(200)
END RECORD

DEFINE m_sales DYNAMIC ARRAY OF RECORD
    s_employeeid LIKE employees.employeeid,
    s_lastname   LIKE employees.lastname,
    s_norders    INTEGER,
    s_freight    DECIMAL(12,2),
    s_years      DECIMAL(5,1)
END RECORD

MAIN
    DEFINE i, n INTEGER
    DEFINE hired_before DATE

    DEFER INTERRUPT
    OPTIONS INPUT WRAP

    CALL nw_connect()
    OPEN WINDOW w_stf WITH FORM "nw_staff"
    CALL fgl_settitle("Staff - " || nw_server_label())

    LET n = stf_load_tree()
    FOR i = 1 TO n
        CALL stf_get_node(i) RETURNING m_tree[i].*
    END FOR
    LET n = stf_load_sales()
    FOR i = 1 TO n
        CALL stf_get_sales(i) RETURNING m_sales[i].*
    END FOR
    DISPLAY stf_anniversaries() TO ann_count
    LET hired_before = MDY(1, 1, 1994)

    DIALOG ATTRIBUTES(UNBUFFERED)
        DISPLAY ARRAY m_tree TO sr_tree.*
            BEFORE ROW
                DISPLAY stf_territories(m_tree[DIALOG.getCurrentRow("sr_tree")].t_employeeid)
                     TO territories
            ON ACTION age ATTRIBUTES(TEXT = "Age")
                MESSAGE m_tree[DIALOG.getCurrentRow("sr_tree")].t_fullname CLIPPED, " is ",
                        stf_age(m_tree[DIALOG.getCurrentRow("sr_tree")].t_employeeid) USING "<<&",
                        " years old"
        END DISPLAY
        DISPLAY ARRAY m_sales TO sr_sales.*
        END DISPLAY
        INPUT BY NAME hired_before ATTRIBUTES(WITHOUT DEFAULTS)
            ON CHANGE hired_before
                DISPLAY stf_hired_before(hired_before) TO hired_count
                MESSAGE stf_five_years_by(hired_before) USING "<<&",
                        " employees reach five years of service in the year from that date"
        END INPUT
        BEFORE DIALOG
            DISPLAY stf_hired_before(hired_before) TO hired_count
        ON ACTION cancel
            EXIT DIALOG
    END DIALOG

    CLOSE WINDOW w_stf
    CALL nw_disconnect()
END MAIN
