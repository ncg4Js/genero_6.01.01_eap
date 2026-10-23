-- nw_rep_statement.4gl: customer statements by country, customer, order and line

SCHEMA northwind

TYPE t_line RECORD
    country      LIKE customers.country,
    customerid   LIKE customers.customerid,
    companyname  LIKE customers.companyname,
    city         LIKE customers.city,
    orderid      LIKE orders.orderid,
    orderdate    LIKE orders.orderdate,
    requireddate LIKE orders.requireddate,
    shippeddate  LIKE orders.shippeddate,
    paydate      DATE,
    freight      LIKE orders.freight,
    productname  LIKE products.productname,
    quantity     LIKE order_details.quantity,
    unitprice    LIKE order_details.unitprice,
    discount     LIKE order_details.discount,
    amount       DECIMAL(12,2),
    late         INTEGER
END RECORD

DEFINE m_from DATE

FUNCTION rep_statement_run(p_file, p_country, p_from)
    DEFINE p_file    STRING
    DEFINE p_country VARCHAR(15)
    DEFINE p_from    DATE
    DEFINE l_line    t_line
    DEFINE l_like    VARCHAR(15)
    DEFINE i         INTEGER

    -- the country pattern uses * and ?, as in the other screens
    LET l_like = p_country
    FOR i = 1 TO LENGTH(l_like)
        CASE l_like[i]
            WHEN "*" LET l_like[i] = "%"
            WHEN "?" LET l_like[i] = "_"
        END CASE
    END FOR

    LET m_from = p_from
    -- payment is due one month after the order date
    DECLARE c_stmt CURSOR FOR
        SELECT c.country, c.customerid, c.companyname, c.city,
               o.orderid, o.orderdate, o.requireddate, o.shippeddate,
               o.orderdate + 1 UNITS MONTH, o.freight,
               p.productname, d.quantity, d.unitprice, d.discount
          FROM customers c, orders o, order_details d, products p
         WHERE o.customerid = c.customerid
           AND d.orderid = o.orderid
           AND p.productid = d.productid
           AND c.country LIKE l_like
           AND o.orderdate >= p_from
         ORDER BY c.country, c.companyname, c.customerid, o.orderdate, o.orderid, p.productname

    START REPORT rep_statement TO FILE p_file
    FOREACH c_stmt INTO l_line.country THRU l_line.discount
        LET l_line.amount = nw_line_total(l_line.unitprice, l_line.quantity, l_line.discount)
        IF l_line.shippeddate IS NULL THEN
            LET l_line.late = TODAY - l_line.requireddate
        ELSE
            LET l_line.late = l_line.shippeddate - l_line.requireddate
        END IF
        OUTPUT TO REPORT rep_statement(l_line.*)
    END FOREACH
    FINISH REPORT rep_statement
    FREE c_stmt
END FUNCTION

-- months between the first and the last order of a customer, and the first order date
FUNCTION customer_history(p_customerid)
    DEFINE p_customerid LIKE customers.customerid
    DEFINE l_months DECIMAL(6,1)
    DEFINE l_first  DATE

    SQL
        SELECT ROUND(MONTHS_BETWEEN(MAX(orderdate), MIN(orderdate)), 1), MIN(orderdate)
          INTO $l_months, $l_first
          FROM orders
         WHERE customerid = $p_customerid
    END SQL
    RETURN l_months, l_first
END FUNCTION

REPORT rep_statement(r)
    DEFINE r t_line
    DEFINE l_months DECIMAL(6,1)
    DEFINE l_first  DATE
    DEFINE l_order_total DECIMAL(12,2)
    DEFINE l_cust_total  DECIMAL(14,2)
    DEFINE l_status CHAR(10)

    OUTPUT
        LEFT MARGIN 0
        TOP MARGIN 2
        BOTTOM MARGIN 2
        PAGE LENGTH 64

    ORDER EXTERNAL BY r.country, r.customerid, r.orderid

    FORMAT
        PAGE HEADER
            PRINT COLUMN 1, "NORTHWIND TRADERS - CUSTOMER STATEMENT",
                  COLUMN 62, "Page ", PAGENO USING "<<&"
            PRINT COLUMN 1, "Orders from ", m_from USING "yyyy-mm-dd",
                  COLUMN 62, TODAY USING "yyyy-mm-dd"
            SKIP 1 LINE

        BEFORE GROUP OF r.country
            SKIP TO TOP OF PAGE
            PRINT "COUNTRY: ", UPSHIFT(r.country)
            SKIP 1 LINE

        BEFORE GROUP OF r.customerid
            CALL customer_history(r.customerid) RETURNING l_months, l_first
            NEED 6 LINES
            PRINT r.companyname CLIPPED, " (", r.city CLIPPED, ")",
                  COLUMN 50, "Customer since ", l_first USING "yyyy-mm-dd"
            PRINT COLUMN 50, "Active ", l_months USING "<<&.&", " months"

        BEFORE GROUP OF r.orderid
            NEED 5 LINES
            CASE
                WHEN r.shippeddate IS NULL
                    LET l_status = "OPEN"
                WHEN r.late > 0
                    LET l_status = "LATE"
                OTHERWISE
                    LET l_status = "ON TIME"
            END CASE
            PRINT COLUMN 3, "Order ", r.orderid USING "######",
                  "  of ", r.orderdate USING "yyyy-mm-dd",
                  "  due ", r.requireddate USING "yyyy-mm-dd",
                  "  shipped ", r.shippeddate USING "yyyy-mm-dd",
                  COLUMN 70, l_status
            PRINT COLUMN 5, "Payment by ", r.paydate USING "yyyy-mm-dd"

        ON EVERY ROW
            PRINT COLUMN 6, r.productname[1,30],
                  COLUMN 38, r.quantity USING "###&",
                  COLUMN 44, r.unitprice USING "##,##&.&&",
                  COLUMN 55, r.discount * 100 USING "#&", "%",
                  COLUMN 61, r.amount USING "###,##&.&&"

        AFTER GROUP OF r.orderid
            LET l_order_total = GROUP SUM(r.amount)
            PRINT COLUMN 44, "Freight", COLUMN 61, r.freight USING "###,##&.&&"
            PRINT COLUMN 44, "Order total", COLUMN 61, l_order_total + r.freight USING "###,##&.&&"
            CASE
                WHEN r.shippeddate IS NULL
                    PRINT COLUMN 6, "Not shipped, ", r.late USING "<<<<&", " days past due"
                WHEN r.late > 0
                    PRINT COLUMN 6, "Delivered ", r.late USING "<<&", " days late"
            END CASE
            SKIP 1 LINE

        AFTER GROUP OF r.customerid
            LET l_cust_total = GROUP SUM(r.amount)
            NEED 3 LINES
            PRINT COLUMN 3, "Customer total (goods)",
                  COLUMN 59, l_cust_total USING "#,###,##&.&&"
            PRINT COLUMN 3, GROUP COUNT(*) USING "<<&", " lines, ",
                  GROUP COUNT(*) WHERE r.discount > 0 USING "<<&", " with discount, ",
                  GROUP SUM(r.quantity) USING "<<<&", " units"
            PRINT "--------------------------------------------------------------------------"

        AFTER GROUP OF r.country
            NEED 3 LINES
            PRINT "TOTAL ", UPSHIFT(r.country),
                  COLUMN 57, GROUP SUM(r.amount) USING "##,###,##&.&&"
            PRINT "Average line ", GROUP AVG(r.amount) USING "<<<,<<&.&&",
                  "   largest line ", GROUP MAX(r.amount) USING "<<<,<<&.&&"

        ON LAST ROW
            SKIP TO TOP OF PAGE
            PRINT "ALL COUNTRIES"
            PRINT "Lines          ", COUNT(*) USING "<<<<&"
            PRINT "Goods          ", SUM(r.amount) USING "<<,<<<,<<&.&&"
            PRINT "Late lines     ", COUNT(*) WHERE r.late > 0 USING "<<<<&"
END REPORT
