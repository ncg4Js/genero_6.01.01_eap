-- nw_rep_sales.4gl: sales by employee, year, month and order

SCHEMA northwind

TYPE t_sale RECORD
    employeeid LIKE employees.employeeid,
    employee   VARCHAR(40),
    yr         INTEGER,
    mon        INTEGER,
    monthname  VARCHAR(12),
    orderid    LIKE orders.orderid,
    orderdate  LIKE orders.orderdate,
    customer   LIKE customers.companyname,
    amount     DECIMAL(12,2),
    rnk        INTEGER
END RECORD

DEFINE m_grand DECIMAL(14,2)
DEFINE m_ref   DATE
DEFINE m_months INTEGER

FUNCTION rep_sales_run(p_file, p_ref, p_months)
    DEFINE p_file   STRING
    DEFINE p_ref    DATE
    DEFINE p_months INTEGER
    DEFINE l_sale   t_sale
    DEFINE l_sql    STRING
    DEFINE l_from   DATE
    DEFINE l_to     DATE

    LET m_ref = p_ref
    LET m_months = p_months
    -- period: from the first day of the month p_months back, to the end of the reference month
    LET l_from = MDY(MONTH(p_ref), 1, YEAR(p_ref)) - p_months UNITS MONTH
    LET l_to = MDY(MONTH(p_ref), 1, YEAR(p_ref)) + 1 UNITS MONTH

    LET l_sql =
        "SELECT e.employeeid, NVL(e.lastname, '') || ', ' || NVL(e.firstname, ''),",
        "       YEAR(o.orderdate), MONTH(o.orderdate),",
        "       TRIM(TO_CHAR(o.orderdate, '%B')),",
        "       o.orderid, o.orderdate, c.companyname,",
        "       SUM(d.unitprice * d.quantity * (1 - d.discount)),",
        "       RANK() OVER (PARTITION BY e.employeeid, YEAR(o.orderdate)",
        "                    ORDER BY SUM(d.unitprice * d.quantity * (1 - d.discount)) DESC)",
        "  FROM employees e",
        "  JOIN orders o ON o.employeeid = e.employeeid",
        "  JOIN customers c ON c.customerid = o.customerid",
        "  JOIN order_details d ON d.orderid = o.orderid",
        " WHERE o.orderdate >= ?",
        "   AND o.orderdate < ?",
        " GROUP BY e.employeeid, e.lastname, e.firstname, o.orderid, o.orderdate, c.companyname",
        " ORDER BY e.lastname, e.employeeid, 3, 4, o.orderdate, o.orderid"

    -- grand total first, for the shares printed per employee
    PREPARE p_grand FROM
        "SELECT NVL(SUM(d.unitprice * d.quantity * (1 - d.discount)), 0)"
        || " FROM orders o JOIN order_details d ON d.orderid = o.orderid"
        || " WHERE o.orderdate >= ?"
        || "   AND o.orderdate < ?"
    EXECUTE p_grand USING l_from, l_to INTO m_grand
    FREE p_grand

    DECLARE c_sales CURSOR FROM l_sql
    START REPORT rep_sales TO FILE p_file
    FOREACH c_sales USING l_from, l_to INTO l_sale.*
        OUTPUT TO REPORT rep_sales(l_sale.*)
    END FOREACH
    FINISH REPORT rep_sales
    FREE c_sales
END FUNCTION

REPORT rep_sales(r)
    DEFINE r t_sale
    DEFINE l_emp_total DECIMAL(14,2)
    DEFINE l_mark CHAR(1)

    OUTPUT
        LEFT MARGIN 0
        TOP MARGIN 1
        BOTTOM MARGIN 1
        PAGE LENGTH 60

    ORDER EXTERNAL BY r.employeeid, r.yr, r.mon

    FORMAT
        PAGE HEADER
            PRINT COLUMN 1, "NORTHWIND TRADERS - SALES BY EMPLOYEE",
                  COLUMN 60, "Page ", PAGENO USING "<<<"
            PRINT COLUMN 1, m_months USING "<<&", " months up to ", m_ref USING "yyyy-mm-dd",
                  COLUMN 60, "Printed ", TODAY USING "yyyy-mm-dd"
            PRINT "--------------------------------------------------------------------------"
            PRINT COLUMN 3, "Order", COLUMN 11, "Date", COLUMN 23, "Customer",
                  COLUMN 58, "Amount", COLUMN 70, "Rank"
            PRINT "--------------------------------------------------------------------------"

        BEFORE GROUP OF r.employeeid
            SKIP TO TOP OF PAGE
            PRINT "Employee ", r.employeeid USING "<<<", ": ", r.employee CLIPPED
            SKIP 1 LINE

        BEFORE GROUP OF r.yr
            NEED 4 LINES
            PRINT COLUMN 2, "Year ", r.yr USING "####"

        BEFORE GROUP OF r.mon
            NEED 3 LINES
            PRINT COLUMN 3, r.monthname CLIPPED

        ON EVERY ROW
            IF r.rnk <= 3 THEN
                LET l_mark = "*"
            ELSE
                LET l_mark = " "
            END IF
            PRINT COLUMN 3, r.orderid USING "######",
                  COLUMN 11, r.orderdate USING "yyyy-mm-dd",
                  COLUMN 23, r.customer[1,30],
                  COLUMN 55, r.amount USING "###,##&.&&",
                  COLUMN 70, r.rnk USING "##&",
                  COLUMN 74, l_mark

        AFTER GROUP OF r.mon
            PRINT COLUMN 55, "----------"
            PRINT COLUMN 5, r.monthname CLIPPED, " total (",
                  GROUP COUNT(*) USING "<<&", " orders)",
                  COLUMN 55, GROUP SUM(r.amount) USING "###,##&.&&"
            SKIP 1 LINE

        AFTER GROUP OF r.yr
            NEED 3 LINES
            PRINT COLUMN 3, "Year ", r.yr USING "####", " total",
                  COLUMN 53, GROUP SUM(r.amount) USING "#,###,##&.&&"
            PRINT COLUMN 3, "Average order",
                  COLUMN 55, GROUP AVG(r.amount) USING "###,##&.&&",
                  COLUMN 68, "Largest ", GROUP MAX(r.amount) USING "<<<,<<&.&&"
            SKIP 1 LINE

        AFTER GROUP OF r.employeeid
            LET l_emp_total = GROUP SUM(r.amount)
            NEED 4 LINES
            PRINT "=========================================================================="
            PRINT "Total ", r.employee CLIPPED,
                  COLUMN 53, l_emp_total USING "#,###,##&.&&"
            IF m_grand > 0 THEN
                PRINT "Share of all sales",
                      COLUMN 58, l_emp_total * 100 / m_grand USING "##&.&", " %"
            END IF
            PRINT "Orders ", GROUP COUNT(*) USING "<<<&",
                  "   top-3 orders of the year: ", GROUP COUNT(*) WHERE r.rnk <= 3 USING "<<&"

        ON LAST ROW
            SKIP TO TOP OF PAGE
            PRINT "GRAND TOTAL", COLUMN 51, SUM(r.amount) USING "##,###,##&.&&"
            PRINT "Orders", COLUMN 58, COUNT(*) USING "#####&"
            PRINT "Average order", COLUMN 55, AVG(r.amount) USING "###,##&.&&"

        PAGE TRAILER
            PRINT "--------------------------------------------------------------------------"
            PRINT COLUMN 1, "Northwind Traders - confidential"
END REPORT
