-- nw_queries_customer.4gl: five customer queries, from simple (1) to complex (5),
-- each shown in its own form. The program is started from a start menu:
--   fglrun nw_queries_customer        start menu (bin/nw_queries_customer.4sm)
--   fglrun nw_queries_customer <1-5>  one query form (the start menu calls it this way)
--
-- Dependencies:
--   IMPORT FGL nw_common (nw_connect, nw_disconnect, nw_server_label)
--   SCHEMA northwind (schema/northwind.sch, found through FGLDBPATH)
--   forms: nw_queries_customer, nw_queries_customer_q1 ... q5 (.per -> .42f)
--   start menu file: nw_queries_customer.4sm (found through FGLRESOURCEPATH)
--   tables: customers, orders, order_details, products, categories, usstates,
--           customercustomerdemo, customerdemographics

IMPORT FGL nw_common

SCHEMA northwind

-- result sets, one per query
DEFINE m_q1 DYNAMIC ARRAY OF RECORD
    q1_id      LIKE customers.customerid,
    q1_code    LIKE customers.customercode,
    q1_company LIKE customers.companyname,
    q1_contact LIKE customers.contactname,
    q1_city    LIKE customers.city,
    q1_country LIKE customers.country,
    q1_segment LIKE customerdemographics.customerdesc,
    q1_state   LIKE usstates.statename
END RECORD

DEFINE m_q2 DYNAMIC ARRAY OF RECORD
    q2_id      LIKE customers.customerid,
    q2_company LIKE customers.companyname,
    q2_norders INTEGER,
    q2_last    DATE
END RECORD

DEFINE m_q3 DYNAMIC ARRAY OF RECORD
    q3_id      LIKE customers.customerid,
    q3_company LIKE customers.companyname,
    q3_country LIKE customers.country,
    q3_norders INTEGER,
    q3_total   DECIMAL(14,2)
END RECORD

DEFINE m_q4 DYNAMIC ARRAY OF RECORD
    q4_id       LIKE customers.customerid,
    q4_company  LIKE customers.companyname,
    q4_segment  LIKE customerdemographics.customerdesc,
    q4_norders  INTEGER,
    q4_nemps    INTEGER,
    q4_nshippers INTEGER,
    q4_freight  DECIMAL(12,2)
END RECORD

DEFINE m_q5 DYNAMIC ARRAY OF RECORD
    q5_country LIKE customers.country,
    q5_rank    INTEGER,
    q5_company LIKE customers.companyname,
    q5_total   DECIMAL(14,2),
    q5_share   DECIMAL(5,1)
END RECORD

MAIN
    DEFER INTERRUPT
    OPTIONS INPUT WRAP

    CASE arg_val(1)
        WHEN "1"
            CALL nw_connect()
            CALL run_q1()
            CALL nw_disconnect()
        WHEN "2"
            CALL nw_connect()
            CALL run_q2()
            CALL nw_disconnect()
        WHEN "3"
            CALL nw_connect()
            CALL run_q3()
            CALL nw_disconnect()
        WHEN "4"
            CALL nw_connect()
            CALL run_q4()
            CALL nw_disconnect()
        WHEN "5"
            CALL nw_connect()
            CALL run_q5()
            CALL nw_disconnect()
        OTHERWISE
            CALL run_start()
    END CASE
END MAIN

-- the start menu: the program only loads it and waits
FUNCTION run_start()
    CALL ui.Interface.loadStartMenu("nw_queries_customer")
    OPEN WINDOW w_start WITH FORM "nw_queries_customer"
    CALL fgl_settitle("Northwind - Customer queries")
    MENU "Customer queries"
        COMMAND "Quit"
            EXIT MENU
    END MENU
    CLOSE WINDOW w_start
END FUNCTION

-- screens ------------------------------------------------------------------

FUNCTION run_q1()
    DEFINE l_where STRING

    OPEN WINDOW w_q1 WITH FORM "nw_queries_customer_q1"
    CALL fgl_settitle("Query 1 - Customers - " || nw_server_label())
    WHILE TRUE
        CONSTRUCT BY NAME l_where ON customers.customercode, customers.companyname,
                                     customers.city, customers.country
        IF int_flag THEN
            LET int_flag = FALSE
            EXIT WHILE
        END IF
        CALL qry1_customers(l_where)
        DISPLAY m_q1.getLength() TO rowcount
        IF m_q1.getLength() = 0 THEN
            MESSAGE "No customer matches"
            CONTINUE WHILE
        END IF
        DISPLAY ARRAY m_q1 TO sr_q1.*
        LET int_flag = FALSE
    END WHILE
    CLOSE WINDOW w_q1
END FUNCTION

FUNCTION run_q2()
    DEFINE ctry VARCHAR(15)

    OPEN WINDOW w_q2 WITH FORM "nw_queries_customer_q2"
    CALL fgl_settitle("Query 2 - Orders per customer - " || nw_server_label())
    LET ctry = "*"
    DIALOG ATTRIBUTES(UNBUFFERED)
        INPUT BY NAME ctry ATTRIBUTES(WITHOUT DEFAULTS)
        END INPUT
        DISPLAY ARRAY m_q2 TO sr_q2.*
        END DISPLAY
        ON ACTION run ATTRIBUTES(TEXT = "Run")
            CALL qry2_order_count(ctry)
            DISPLAY m_q2.getLength() TO rowcount
        ON ACTION cancel
            EXIT DIALOG
    END DIALOG
    CLOSE WINDOW w_q2
END FUNCTION

FUNCTION run_q3()
    DEFINE minsales DECIMAL(12,2)

    OPEN WINDOW w_q3 WITH FORM "nw_queries_customer_q3"
    CALL fgl_settitle("Query 3 - Sales per customer - " || nw_server_label())
    LET minsales = 10000
    DIALOG ATTRIBUTES(UNBUFFERED)
        INPUT BY NAME minsales ATTRIBUTES(WITHOUT DEFAULTS)
        END INPUT
        DISPLAY ARRAY m_q3 TO sr_q3.*
        END DISPLAY
        ON ACTION run ATTRIBUTES(TEXT = "Run")
            CALL qry3_sales(minsales)
            DISPLAY m_q3.getLength() TO rowcount
        ON ACTION cancel
            EXIT DIALOG
    END DIALOG
    CLOSE WINDOW w_q3
END FUNCTION

FUNCTION run_q4()
    DEFINE categoryid LIKE products.categoryid

    OPEN WINDOW w_q4 WITH FORM "nw_queries_customer_q4"
    CALL fgl_settitle("Query 4 - Buyers of a category - " || nw_server_label())
    CALL fill_categories(ui.ComboBox.forName("categoryid"))
    LET categoryid = 1
    DIALOG ATTRIBUTES(UNBUFFERED)
        INPUT BY NAME categoryid ATTRIBUTES(WITHOUT DEFAULTS)
        END INPUT
        DISPLAY ARRAY m_q4 TO sr_q4.*
        END DISPLAY
        ON ACTION run ATTRIBUTES(TEXT = "Run")
            CALL qry4_category_buyers(categoryid)
            DISPLAY m_q4.getLength() TO rowcount
        ON ACTION cancel
            EXIT DIALOG
    END DIALOG
    CLOSE WINDOW w_q4
END FUNCTION

FUNCTION run_q5()
    DEFINE topn INTEGER

    OPEN WINDOW w_q5 WITH FORM "nw_queries_customer_q5"
    CALL fgl_settitle("Query 5 - Top customers per country - " || nw_server_label())
    LET topn = 3
    DIALOG ATTRIBUTES(UNBUFFERED)
        INPUT BY NAME topn ATTRIBUTES(WITHOUT DEFAULTS)
        END INPUT
        DISPLAY ARRAY m_q5 TO sr_q5.*
        END DISPLAY
        ON ACTION run ATTRIBUTES(TEXT = "Run")
            CALL qry5_top_per_country(topn)
            DISPLAY m_q5.getLength() TO rowcount
        ON ACTION cancel
            EXIT DIALOG
    END DIALOG
    CLOSE WINDOW w_q5
END FUNCTION

-- categories for the combobox of query 4
FUNCTION fill_categories(p_cb)
    DEFINE p_cb   ui.ComboBox
    DEFINE l_id   LIKE categories.categoryid
    DEFINE l_name LIKE categories.categoryname

    CALL p_cb.clear()
    DECLARE c_qcat CURSOR FOR
        SELECT categoryid, categoryname FROM categories ORDER BY categoryname
    FOREACH c_qcat INTO l_id, l_name
        CALL p_cb.addItem(l_id, l_name)
    END FOREACH
    FREE c_qcat
END FUNCTION

-- queries ------------------------------------------------------------------

-- 1. Customers matching a condition, with US state and segment (the query of cus_search)
--    p_where: a condition on customers columns, e.g. "customers.country = 'USA'"
FUNCTION qry1_customers(p_where)
    DEFINE p_where STRING
    DEFINE l_sql   STRING
    DEFINE i       INTEGER

    IF p_where IS NULL THEN
        LET p_where = "1=1"
    END IF
    LET l_sql = "SELECT customers.customerid, customers.customercode, customers.companyname,",
                "       customers.contactname, customers.city, customers.country,",
                "       (SELECT MIN(d.customerdesc)",
                "          FROM customercustomerdemo cc, customerdemographics d",
                "         WHERE cc.customerid = customers.customercode",
                "           AND d.customertypeid = cc.customertypeid),",
                "       usstates.statename",
                "  FROM customers LEFT OUTER JOIN usstates ON usstates.stateabbr = customers.region",
                " WHERE ", p_where,
                " ORDER BY customers.companyname"
    CALL m_q1.clear()
    DECLARE c_q1 CURSOR FROM l_sql
    LET i = 1
    FOREACH c_q1 INTO m_q1[i].*
        LET i = i + 1
    END FOREACH
    CALL m_q1.deleteElement(i)
    FREE c_q1
END FUNCTION

-- 2. Order count and last order date per customer (outer join + GROUP BY)
--    p_country: pattern with * and ? (MATCHES), use "*" for all
FUNCTION qry2_order_count(p_country)
    DEFINE p_country VARCHAR(15)
    DEFINE i         INTEGER

    IF p_country IS NULL THEN
        LET p_country = "*"
    END IF
    CALL m_q2.clear()
    DECLARE c_q2 CURSOR FROM
        "SELECT c.customerid, c.companyname, COUNT(o.orderid), MAX(o.orderdate)"
        || "  FROM customers c LEFT OUTER JOIN orders o ON o.customerid = c.customerid"
        || " WHERE c.country MATCHES ?"
        || " GROUP BY c.customerid, c.companyname"
        || " ORDER BY 3 DESC, c.companyname"
    LET i = 1
    FOREACH c_q2 USING p_country INTO m_q2[i].*
        LET i = i + 1
    END FOREACH
    CALL m_q2.deleteElement(i)
    FREE c_q2
END FUNCTION

-- 3. Total sales per customer, only customers above a minimum (three tables, HAVING)
FUNCTION qry3_sales(p_min)
    DEFINE p_min DECIMAL(12,2)
    DEFINE i     INTEGER

    IF p_min IS NULL THEN
        LET p_min = 0
    END IF
    CALL m_q3.clear()
    DECLARE c_q3 CURSOR FROM
        "SELECT c.customerid, c.companyname, c.country, COUNT(DISTINCT o.orderid),"
        || "       SUM(d.unitprice * d.quantity * (1 - d.discount))"
        || "  FROM customers c"
        || "  JOIN orders o ON o.customerid = c.customerid"
        || "  JOIN order_details d ON d.orderid = o.orderid"
        || " GROUP BY c.customerid, c.companyname, c.country"
        || " HAVING SUM(d.unitprice * d.quantity * (1 - d.discount)) >= ?"
        || " ORDER BY 5 DESC"
    LET i = 1
    FOREACH c_q3 USING p_min INTO m_q3[i].*
        LET i = i + 1
    END FOREACH
    CALL m_q3.deleteElement(i)
    FREE c_q3
END FUNCTION

-- 4. Customers who bought from a category: order statistics from a derived table,
--    segment from a subquery, category filter with EXISTS
FUNCTION qry4_category_buyers(p_categoryid)
    DEFINE p_categoryid LIKE products.categoryid
    DEFINE i            INTEGER

    CALL m_q4.clear()
    DECLARE c_q4 CURSOR FROM
        "SELECT c.customerid, c.companyname,"
        || "       (SELECT MIN(dg.customerdesc)"
        || "          FROM customercustomerdemo cc, customerdemographics dg"
        || "         WHERE cc.customerid = c.customercode"
        || "           AND dg.customertypeid = cc.customertypeid),"
        || "       st.norders, st.nemps, st.nshippers, st.freight"
        || "  FROM customers c,"
        || "       (SELECT customerid, COUNT(*) norders, COUNT(DISTINCT employeeid) nemps,"
        || "               COUNT(DISTINCT shipvia) nshippers, SUM(freight) freight"
        || "          FROM orders GROUP BY customerid) st"
        || " WHERE st.customerid = c.customerid"
        || "   AND EXISTS (SELECT 1"
        || "                 FROM orders o, order_details d, products p"
        || "                WHERE o.customerid = c.customerid"
        || "                  AND d.orderid = o.orderid"
        || "                  AND p.productid = d.productid"
        || "                  AND p.categoryid = ?)"
        || " ORDER BY st.norders DESC, c.companyname"
    LET i = 1
    FOREACH c_q4 USING p_categoryid INTO m_q4[i].*
        LET i = i + 1
    END FOREACH
    CALL m_q4.deleteElement(i)
    FREE c_q4
END FUNCTION

-- 5. Top customers per country: totals per customer (inner), rank and country share
--    with window functions (middle), top N filter (outer)
FUNCTION qry5_top_per_country(p_top)
    DEFINE p_top INTEGER
    DEFINE i     INTEGER

    IF p_top IS NULL OR p_top <= 0 THEN
        LET p_top = 3
    END IF
    CALL m_q5.clear()
    DECLARE c_q5 CURSOR FROM
        "SELECT country, rnk, companyname, total, share"
        || "  FROM (SELECT t.country, t.companyname, t.total,"
        || "               RANK() OVER (PARTITION BY t.country ORDER BY t.total DESC) rnk,"
        || "               ROUND(100 * t.total / SUM(t.total) OVER (PARTITION BY t.country), 1) share"
        || "          FROM (SELECT c.customerid, c.country, c.companyname,"
        || "                       SUM(d.unitprice * d.quantity * (1 - d.discount)) total"
        || "                  FROM customers c, orders o, order_details d"
        || "                 WHERE o.customerid = c.customerid"
        || "                   AND d.orderid = o.orderid"
        || "                 GROUP BY c.customerid, c.country, c.companyname) t) r"
        || " WHERE rnk <= ?"
        || " ORDER BY country, rnk"
    LET i = 1
    FOREACH c_q5 USING p_top INTO m_q5[i].*
        LET i = i + 1
    END FOREACH
    CALL m_q5.deleteElement(i)
    FREE c_q5
END FUNCTION
