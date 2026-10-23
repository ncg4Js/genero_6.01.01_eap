-- nw_customers.4gl: Northwind customers (search, countries, new customer)
IMPORT FGL nw_common
IMPORT FGL nw_customers_db

SCHEMA northwind

DEFINE m_customers DYNAMIC ARRAY OF RECORD
    c_customerid   LIKE customers.customerid,
    c_customercode LIKE customers.customercode,
    c_companyname  LIKE customers.companyname,
    c_contactname  LIKE customers.contactname,
    c_city         LIKE customers.city,
    c_country      LIKE customers.country,
    c_segment      LIKE customerdemographics.customerdesc,
    c_statename    LIKE usstates.statename
END RECORD

DEFINE m_countries DYNAMIC ARRAY OF RECORD
    k_country LIKE customers.country,
    k_ncust   INTEGER,
    k_cities  VARCHAR(400)
END RECORD

MAIN
    DEFINE l_where STRING
    DEFINE i, n INTEGER

    DEFER INTERRUPT
    OPTIONS INPUT WRAP

    CALL nw_connect()
    OPEN WINDOW w_cus WITH FORM "nw_customers"
    CALL fgl_settitle("Customers - " || nw_server_label())

    LET n = cus_load_countries()
    FOR i = 1 TO n
        CALL cus_get_country(i) RETURNING m_countries[i].*
    END FOR
    DISPLAY cus_without_orders() TO noorder_count

    MENU "Customers"
        COMMAND "Search"
            CONSTRUCT BY NAME l_where ON customers.customercode, customers.companyname,
                                         customers.city, customers.country
            IF int_flag THEN
                LET int_flag = FALSE
            ELSE
                CALL show_customers(l_where)
            END IF
        COMMAND "Countries"
            DISPLAY ARRAY m_countries TO sr_countries.* ATTRIBUTES(UNBUFFERED)
            LET int_flag = FALSE
        COMMAND "New"
            CALL new_customer()
        COMMAND "Quit"
            EXIT MENU
    END MENU

    CLOSE WINDOW w_cus
    CALL nw_disconnect()
END MAIN

FUNCTION show_customers(p_where)
    DEFINE p_where STRING
    DEFINE i, n INTEGER
    DEFINE l_last DATE
    DEFINE l_days INTEGER
    DEFINE l_overdue INTEGER
    DEFINE l_text STRING

    LET n = cus_search(p_where)
    CALL m_customers.clear()
    FOR i = 1 TO n
        CALL cus_get_row(i) RETURNING m_customers[i].*
    END FOR
    IF n = 0 THEN
        MESSAGE "No customer matches"
        RETURN
    END IF
    DISPLAY ARRAY m_customers TO sr_customers.* ATTRIBUTES(UNBUFFERED)
        BEFORE ROW
            CALL cus_last_order(m_customers[arr_curr()].c_customerid)
                 RETURNING l_last, l_days, l_overdue
            IF l_last IS NULL THEN
                MESSAGE "No order yet"
            ELSE
                MESSAGE "Last order ", l_last USING "dd/mm/yyyy", ", ", l_days USING "<<<<&", " days ago, ",
                        l_overdue USING "<<&", " open orders older than a month"
            END IF
        ON ACTION same_code ATTRIBUTES(TEXT = "Same code prefix")
            MESSAGE cus_same_code_prefix(m_customers[arr_curr()].c_customercode) USING "<<&",
                    " customers share the code prefix"
        ON ACTION recent_orders ATTRIBUTES(TEXT = "Last 2 orders")
            LET l_text = cus_recent_orders(m_customers[arr_curr()].c_customerid)
            IF l_text IS NULL THEN
                MESSAGE "No order yet"
            ELSE
                MESSAGE "Last orders: ", l_text
            END IF
        ON ACTION top_customers ATTRIBUTES(TEXT = "Top 3")
            MESSAGE "Most orders: ", cus_top_customers()
    END DISPLAY
    LET int_flag = FALSE
END FUNCTION

FUNCTION new_customer()
    DEFINE l_rec RECORD LIKE customers.*
    DEFINE l_status INTEGER
    DEFINE l_id LIKE customers.customerid

    INITIALIZE l_rec.* TO NULL
    PROMPT "Customer code (5 letters): " FOR l_rec.customercode
    IF int_flag OR l_rec.customercode IS NULL THEN
        LET int_flag = FALSE
        RETURN
    END IF
    IF cus_code_exists(l_rec.customercode) THEN
        ERROR "Code already used"
        RETURN
    END IF
    PROMPT "Company name: " FOR l_rec.companyname
    PROMPT "Country: " FOR l_rec.country
    IF int_flag THEN
        LET int_flag = FALSE
        RETURN
    END IF
    CALL cus_insert(l_rec.*) RETURNING l_status, l_id
    IF l_status = 0 THEN
        MESSAGE "Customer ", l_id USING "<<<<<", " created"
    ELSE
        ERROR "Insert failed: ", l_status
    END IF
END FUNCTION
