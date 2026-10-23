-- nw_orders.4gl: Northwind order desk (search, lines, ship, reprice, surcharge)

SCHEMA northwind

DEFINE m_orders DYNAMIC ARRAY OF RECORD
    o_orderid   LIKE orders.orderid,
    o_orderdate LIKE orders.orderdate,
    o_customer  LIKE customers.companyname,
    o_employee  LIKE employees.lastname,
    o_shipper   LIKE shippers.companyname,
    o_shipped   LIKE orders.shippeddate
END RECORD

DEFINE m_lines DYNAMIC ARRAY OF RECORD
    l_productid   LIKE order_details.productid,
    l_productname LIKE products.productname,
    l_unitprice   LIKE order_details.unitprice,
    l_quantity    LIKE order_details.quantity,
    l_discount    LIKE order_details.discount,
    l_total       DECIMAL(12,2)
END RECORD

MAIN
    DEFINE l_where STRING
    DEFINE shipvia LIKE orders.shipvia

    DEFER INTERRUPT
    OPTIONS INPUT WRAP

    CALL nw_connect()
    OPEN WINDOW w_ord WITH FORM "nw_orders"
    CALL fgl_settitle("Order desk - " || nw_server_label())
    CALL ord_fill_shippers(ui.ComboBox.forName("shipvia"))
    DISPLAY ord_late_count() TO late_count
    MESSAGE ord_very_late_count() USING "<<<&", " orders shipped over a week late, ",
            ord_open_due_count(TODAY) USING "<<<&", " open orders due by the end of next month"

    WHILE TRUE
        CONSTRUCT BY NAME l_where ON orders.orderid, orders.orderdate,
                                     customers.companyname, orders.shipcountry,
                                     employees.lastname
        IF int_flag THEN
            LET int_flag = FALSE
            EXIT WHILE
        END IF
        IF load_orders(l_where) = 0 THEN
            MESSAGE "No order matches"
            CONTINUE WHILE
        END IF

        DIALOG ATTRIBUTES(UNBUFFERED)
            DISPLAY ARRAY m_orders TO sr_orders.*
                BEFORE ROW
                    CALL load_lines(m_orders[DIALOG.getCurrentRow("sr_orders")].o_orderid)
                    CALL show_dates(m_orders[DIALOG.getCurrentRow("sr_orders")].o_orderid)
            END DISPLAY
            DISPLAY ARRAY m_lines TO sr_lines.*
            END DISPLAY
            INPUT BY NAME shipvia
            END INPUT

            ON ACTION ship ATTRIBUTES(TEXT = "Ship")
                CALL do_ship(m_orders[DIALOG.getCurrentRow("sr_orders")].o_orderid, shipvia)
            ON ACTION reprice ATTRIBUTES(TEXT = "Reprice")
                CALL do_reprice(m_orders[DIALOG.getCurrentRow("sr_orders")].o_orderid)
            ON ACTION surcharge ATTRIBUTES(TEXT = "Freight +5%")
                CALL do_surcharge(m_orders[DIALOG.getCurrentRow("sr_orders")].o_orderid)
            ON ACTION neworder ATTRIBUTES(TEXT = "Copy as new order")
                CALL do_copy(m_orders[DIALOG.getCurrentRow("sr_orders")].o_orderid)
            ON ACTION cancel
                EXIT DIALOG
        END DIALOG
    END WHILE

    CLOSE WINDOW w_ord
    CALL nw_disconnect()
END MAIN

FUNCTION load_orders(p_where)
    DEFINE p_where STRING
    DEFINE i, n INTEGER

    LET n = ord_search(p_where)
    CALL m_orders.clear()
    FOR i = 1 TO n
        CALL ord_get_row(i) RETURNING m_orders[i].*
    END FOR
    RETURN n
END FUNCTION

FUNCTION load_lines(p_orderid)
    DEFINE p_orderid LIKE orders.orderid
    DEFINE i, n INTEGER

    LET n = ord_load_lines(p_orderid)
    CALL m_lines.clear()
    FOR i = 1 TO n
        CALL ord_get_line(i) RETURNING m_lines[i].*
    END FOR
END FUNCTION

-- payment and follow-up dates of the current order
FUNCTION show_dates(p_orderid)
    DEFINE p_orderid LIKE orders.orderid
    DEFINE l_due, l_followup DATE

    LET l_due = ord_payment_due(p_orderid)
    LET l_followup = ord_followup_date(p_orderid)
    IF l_followup IS NULL THEN
        MESSAGE "Payment due ", l_due USING "yyyy-mm-dd", ", not shipped yet"
    ELSE
        MESSAGE "Payment due ", l_due USING "yyyy-mm-dd",
                ", follow-up call ", l_followup USING "yyyy-mm-dd"
    END IF
END FUNCTION

FUNCTION do_ship(p_orderid, p_shipvia)
    DEFINE p_orderid LIKE orders.orderid
    DEFINE p_shipvia LIKE orders.shipvia
    DEFINE l_status INTEGER

    LET l_status = ord_ship(p_orderid, p_shipvia)
    CASE
        WHEN l_status = 0
            MESSAGE "Order ", p_orderid USING "<<<<<<", " shipped"
        WHEN l_status = 1
            ERROR "Order already shipped"
        WHEN l_status = -244
            ERROR "Order is being changed by another user"
        OTHERWISE
            ERROR "Ship failed: ", l_status
    END CASE
END FUNCTION

FUNCTION do_reprice(p_orderid)
    DEFINE p_orderid LIKE orders.orderid

    IF ord_reprice(p_orderid) = 0 THEN
        CALL load_lines(p_orderid)
        MESSAGE "Prices reset to the catalogue"
    ELSE
        ERROR "Reprice failed"
    END IF
END FUNCTION

FUNCTION do_surcharge(p_orderid)
    DEFINE p_orderid LIKE orders.orderid

    IF ord_freight_surcharge(p_orderid, 5) = 0 THEN
        MESSAGE "Freight raised by 5%"
    ELSE
        ERROR "Surcharge failed"
    END IF
END FUNCTION

-- copies an order (header and lines) as a new order dated today
FUNCTION do_copy(p_orderid)
    DEFINE p_orderid LIKE orders.orderid
    DEFINE l_rec RECORD LIKE orders.*
    DEFINE l_status INTEGER
    DEFINE l_newid LIKE orders.orderid
    DEFINE i INTEGER

    CALL ord_load_header(p_orderid, l_rec.*) RETURNING l_status, l_rec.*
    IF l_status != 0 THEN
        ERROR "Order not found"
        RETURN
    END IF
    LET l_rec.requireddate = TODAY + 14
    LET l_rec.shippeddate = NULL

    CALL ord_clear_new_lines()
    FOR i = 1 TO m_lines.getLength()
        CALL ord_add_new_line(m_lines[i].l_productid, m_lines[i].l_unitprice,
                              m_lines[i].l_quantity, m_lines[i].l_discount)
    END FOR
    CALL ord_create(l_rec.*) RETURNING l_status, l_newid
    IF l_status = 0 THEN
        MESSAGE "New order ", l_newid USING "<<<<<<", " created"
    ELSE
        ERROR "Copy failed: ", l_status
    END IF
END FUNCTION
