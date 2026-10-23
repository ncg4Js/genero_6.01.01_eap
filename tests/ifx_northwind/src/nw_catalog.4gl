-- nw_catalog.4gl: Northwind catalogue (products, categories, suppliers)

SCHEMA northwind

DEFINE m_products DYNAMIC ARRAY OF RECORD
    p_productid    LIKE products.productid,
    p_productname  LIKE products.productname,
    p_categoryname LIKE categories.categoryname,
    p_supplier     LIKE suppliers.companyname,
    p_unitprice    LIKE products.unitprice,
    p_unitsinstock LIKE products.unitsinstock,
    p_status       VARCHAR(12)
END RECORD

MAIN
    DEFINE l_where STRING
    DEFINE categoryid LIKE products.categoryid
    DEFINE pct DECIMAL(5,2)

    DEFER INTERRUPT
    OPTIONS INPUT WRAP

    CALL nw_connect()
    OPEN WINDOW w_cat WITH FORM "nw_catalog"
    CALL fgl_settitle("Catalogue - " || nw_server_label())
    CALL cat_fill_categories(ui.ComboBox.forName("categoryid"))
    DISPLAY cat_idle_suppliers() TO idle_count

    MENU "Catalogue"
        COMMAND "Search"
            CONSTRUCT BY NAME l_where ON products.productname, products.unitprice,
                                         products.unitsinstock
            IF int_flag THEN
                LET int_flag = FALSE
            ELSE
                CALL show_products(l_where)
            END IF
        COMMAND "Prices"
            INPUT BY NAME categoryid, pct
            IF int_flag THEN
                LET int_flag = FALSE
            ELSE
                CALL change_prices(categoryid, pct)
            END IF
        COMMAND "Top 10"
            CALL show_top()
        COMMAND "Statistics"
            CALL show_statistics()
        COMMAND "Quit"
            EXIT MENU
    END MENU

    CLOSE WINDOW w_cat
    CALL nw_disconnect()
END MAIN

FUNCTION show_products(p_where)
    DEFINE p_where STRING
    DEFINE i, n INTEGER

    LET n = cat_search(p_where)
    CALL m_products.clear()
    FOR i = 1 TO n
        CALL cat_get_row(i) RETURNING m_products[i].*
    END FOR
    IF n = 0 THEN
        MESSAGE "No product matches"
        RETURN
    END IF
    DISPLAY ARRAY m_products TO sr_products.* ATTRIBUTES(UNBUFFERED)
        ON ACTION same_prefix ATTRIBUTES(TEXT = "Same prefix")
            MESSAGE cat_same_prefix(m_products[arr_curr()].p_productname)
                    USING "<<<", " products start the same way"
    END DISPLAY
    LET int_flag = FALSE
END FUNCTION

FUNCTION change_prices(p_categoryid, p_pct)
    DEFINE p_categoryid LIKE products.categoryid
    DEFINE p_pct DECIMAL(5,2)
    DEFINE l_status, l_rows INTEGER

    IF p_categoryid IS NULL OR p_pct IS NULL THEN
        ERROR "Choose a category and a percentage"
        RETURN
    END IF
    CALL cat_change_prices(p_categoryid, p_pct) RETURNING l_status, l_rows
    IF l_status = 0 THEN
        MESSAGE l_rows USING "<<<", " prices changed"
    ELSE
        ERROR "Price change failed: ", l_status
    END IF
END FUNCTION

FUNCTION show_top()
    DEFINE i, n INTEGER
    DEFINE l_name LIKE products.productname
    DEFINE l_price LIKE products.unitprice
    DEFINE l_text STRING

    LET n = cat_top_prices()
    LET l_text = "Most expensive products:\n"
    FOR i = 1 TO n
        CALL cat_get_top(i) RETURNING l_name, l_price
        LET l_text = l_text, l_name CLIPPED, "  ", l_price USING "##,##&.&&", "\n"
    END FOR
    CALL nw_info("Top 10", l_text)
END FUNCTION

FUNCTION show_statistics()
    DEFINE l_text STRING

    LET l_text = "Names starting with C: ", cat_count_by_name("C*") USING "<<<", "\n",
                 "Names from A to F: ", cat_count_range("A", "F") USING "<<<", "\n",
                 "Idle suppliers: ", cat_idle_suppliers() USING "<<<"
    CALL nw_info("Statistics", l_text)
END FUNCTION
