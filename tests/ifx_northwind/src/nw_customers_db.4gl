-- nw_customers_db.4gl: SQL for customers, demographics and US states

SCHEMA northwind

TYPE t_customer RECORD
    customerid   LIKE customers.customerid,
    customercode LIKE customers.customercode,
    companyname  LIKE customers.companyname,
    contactname  LIKE customers.contactname,
    city         LIKE customers.city,
    country      LIKE customers.country,
    segment      LIKE customerdemographics.customerdesc,
    statename    LIKE usstates.statename
END RECORD

DEFINE m_customers DYNAMIC ARRAY OF t_customer
DEFINE m_countries DYNAMIC ARRAY OF RECORD
    country LIKE customers.country,
    ncust   INTEGER,
    cities  VARCHAR(400)
END RECORD

-- customers matching a CONSTRUCT condition
FUNCTION cus_search(p_where)
    DEFINE p_where STRING
    DEFINE l_sql   STRING
    DEFINE i       INTEGER

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
    CALL m_customers.clear()
    DECLARE c_cus CURSOR FROM l_sql
    LET i = 1
    FOREACH c_cus INTO m_customers[i].*
        LET i = i + 1
    END FOREACH
    CALL m_customers.deleteElement(i)
    FREE c_cus
    RETURN m_customers.getLength()
END FUNCTION

FUNCTION cus_get_row(p_idx)
    DEFINE p_idx INTEGER
    RETURN m_customers[p_idx].*
END FUNCTION

-- customers and cities per country
FUNCTION cus_load_countries()
    DEFINE i INTEGER
    DEFINE l_country LIKE customers.country
    DEFINE l_city LIKE customers.city

    CALL m_countries.clear()
    DECLARE c_ctry CURSOR FOR
        SELECT country, COUNT(*)
          FROM customers
         GROUP BY country
         ORDER BY 2 DESC, country
    DECLARE c_city CURSOR FOR
        SELECT DISTINCT city
          FROM customers
         WHERE country = l_country
           AND city IS NOT NULL
         ORDER BY city
    LET i = 1
    FOREACH c_ctry INTO m_countries[i].country, m_countries[i].ncust
        LET l_country = m_countries[i].country
        FOREACH c_city INTO l_city
            IF m_countries[i].cities IS NOT NULL THEN
                LET m_countries[i].cities = m_countries[i].cities, ", "
            END IF
            LET m_countries[i].cities = m_countries[i].cities, l_city
        END FOREACH
        LET i = i + 1
    END FOREACH
    CALL m_countries.deleteElement(i)
    RETURN m_countries.getLength()
END FUNCTION

FUNCTION cus_get_country(p_idx)
    DEFINE p_idx INTEGER
    RETURN m_countries[p_idx].*
END FUNCTION

-- customers that never ordered
FUNCTION cus_without_orders()
    DEFINE l_count INTEGER

    PREPARE p_noord FROM
        "SELECT COUNT(*) FROM (SELECT customerid FROM customers MINUS SELECT customerid FROM orders)"
    EXECUTE p_noord INTO l_count
    FREE p_noord
    RETURN l_count
END FUNCTION

-- the three customers with the most orders
FUNCTION cus_top_customers()
    DEFINE l_name    LIKE customers.companyname
    DEFINE l_norders INTEGER
    DEFINE l_text    STRING
    DEFINE l_sql     STRING

    LET l_sql = "SELECT FIRST 3 c.companyname, COUNT(*) norders",
                "  FROM customers c, orders o",
                " WHERE o.customerid = c.customerid",
                " GROUP BY c.customerid, c.companyname",
                " ORDER BY 2 DESC, 1"
    PREPARE p_top FROM l_sql
    DECLARE c_top CURSOR FOR p_top
    FOREACH c_top INTO l_name, l_norders
        IF l_text IS NOT NULL THEN
            LET l_text = l_text, ", "
        END IF
        LET l_text = l_text, l_name CLIPPED, " (", l_norders USING "<<<&", ")"
    END FOREACH
    FREE c_top
    FREE p_top
    RETURN l_text
END FUNCTION

-- the two most recent orders of a customer
FUNCTION cus_recent_orders(p_customerid)
    DEFINE p_customerid LIKE customers.customerid
    DEFINE l_orderid    LIKE orders.orderid
    DEFINE l_orderdate  LIKE orders.orderdate
    DEFINE l_text       STRING

    DECLARE c_recent CURSOR FOR
        SELECT FIRST 2 orderid, orderdate
          FROM orders
         WHERE customerid = p_customerid
         ORDER BY orderdate DESC, orderid DESC
    FOREACH c_recent INTO l_orderid, l_orderdate
        IF l_text IS NOT NULL THEN
            LET l_text = l_text, ", "
        END IF
        LET l_text = l_text, "#", l_orderid USING "<<<<&", " of ", l_orderdate USING "dd/mm/yyyy"
    END FOREACH
    FREE c_recent
    RETURN l_text
END FUNCTION

-- customers sharing the first two letters of a code
FUNCTION cus_same_code_prefix(p_code)
    DEFINE p_code   LIKE customers.customercode
    DEFINE l_prefix CHAR(2)
    DEFINE l_count  INTEGER

    LET l_prefix = p_code
    SELECT COUNT(*) INTO l_count FROM customers
     WHERE customercode[1,2] = l_prefix
    RETURN l_count
END FUNCTION

-- last order date of a customer, days since, and open orders older than a month
FUNCTION cus_last_order(p_customerid)
    DEFINE p_customerid LIKE customers.customerid
    DEFINE orderdate    LIKE orders.orderdate
    DEFINE l_days       INTEGER
    DEFINE l_overdue    INTEGER

    SELECT MAX(o.orderdate) INTO orderdate FROM orders o WHERE o.customerid = p_customerid
    IF orderdate IS NULL THEN
        RETURN NULL, NULL, 0
    END IF
    LET l_days = TODAY - orderdate
    PREPARE p_overdue FROM
        "SELECT COUNT(*) FROM orders"
        || " WHERE customerid = ? AND shippeddate IS NULL"
        || "   AND orderdate + 1 UNITS MONTH < TODAY"
    EXECUTE p_overdue USING p_customerid INTO l_overdue
    FREE p_overdue
    RETURN orderdate, l_days, l_overdue
END FUNCTION

-- new customer; the key comes from the customers sequence
FUNCTION cus_insert(p_rec)
    DEFINE p_rec RECORD LIKE customers.*
    DEFINE l_id  LIKE customers.customerid

    TRY
        BEGIN WORK
        SQL
            INSERT INTO customers (customerid, customercode, companyname, contactname,
                                   contacttitle, address, city, region, postalcode,
                                   country, phone, fax)
            VALUES (SEQ_NW_CUSTOMERS.NEXTVAL, UPPER($p_rec.customercode), $p_rec.companyname,
                    $p_rec.contactname, $p_rec.contacttitle, $p_rec.address, $p_rec.city,
                    $p_rec.region, $p_rec.postalcode, $p_rec.country, $p_rec.phone, $p_rec.fax)
        END SQL
        SQL
            SELECT SEQ_NW_CUSTOMERS.CURRVAL INTO $l_id FROM systables WHERE tabid = 1
        END SQL
        COMMIT WORK
    CATCH
        ROLLBACK WORK
        RETURN sqlca.sqlcode, NULL
    END TRY
    RETURN 0, l_id
END FUNCTION

-- customer code already used?
FUNCTION cus_code_exists(p_code)
    DEFINE p_code  LIKE customers.customercode
    DEFINE l_count INTEGER

    SELECT COUNT(*) INTO l_count FROM customers
     WHERE UPPER(customercode) = UPPER(p_code)
    RETURN l_count > 0
END FUNCTION
