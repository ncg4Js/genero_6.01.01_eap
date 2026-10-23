-- nw_orders_db.4gl: SQL for the order desk

SCHEMA northwind

TYPE t_order_row RECORD
    orderid     LIKE orders.orderid,
    orderdate   LIKE orders.orderdate,
    customer    LIKE customers.companyname,
    employee    LIKE employees.lastname,
    shipper     LIKE shippers.companyname,
    shippeddate LIKE orders.shippeddate
END RECORD

TYPE t_line RECORD
    productid   LIKE order_details.productid,
    productname LIKE products.productname,
    unitprice   LIKE order_details.unitprice,
    quantity    LIKE order_details.quantity,
    discount    LIKE order_details.discount,
    linetotal   DECIMAL(12,2)
END RECORD

DEFINE m_orders DYNAMIC ARRAY OF t_order_row
DEFINE m_lines  DYNAMIC ARRAY OF t_line
DEFINE m_new    DYNAMIC ARRAY OF t_line

-- list of orders matching a CONSTRUCT condition
FUNCTION ord_search(p_where)
    DEFINE p_where STRING
    DEFINE l_sql   STRING
    DEFINE i       INTEGER

    LET l_sql = "SELECT FIRST 300 orders.orderid, orders.orderdate, customers.companyname,",
                "       employees.lastname, shippers.companyname, orders.shippeddate",
                "  FROM orders, customers, OUTER employees, OUTER shippers",
                " WHERE orders.customerid = customers.customerid",
                "   AND orders.employeeid = employees.employeeid",
                "   AND orders.shipvia = shippers.shipperid",
                "   AND ", p_where,
                " ORDER BY orders.orderdate DESC, orders.orderid DESC"
    CALL m_orders.clear()
    DECLARE c_ord CURSOR FROM l_sql
    LET i = 1
    FOREACH c_ord INTO m_orders[i].*
        LET i = i + 1
    END FOREACH
    CALL m_orders.deleteElement(i)
    FREE c_ord
    RETURN m_orders.getLength()
END FUNCTION

FUNCTION ord_get_row(p_idx)
    DEFINE p_idx INTEGER
    RETURN m_orders[p_idx].*
END FUNCTION

-- lines of one order
FUNCTION ord_load_lines(p_orderid)
    DEFINE p_orderid LIKE orders.orderid
    DEFINE i INTEGER

    CALL m_lines.clear()
    DECLARE c_lines CURSOR FOR
        SELECT d.productid, p.productname, d.unitprice, d.quantity, d.discount,
               d.unitprice * d.quantity * (1 - d.discount)
          FROM order_details d, products p
         WHERE d.orderid = p_orderid
           AND p.productid = d.productid
         ORDER BY p.productname
    LET i = 1
    FOREACH c_lines INTO m_lines[i].*
        LET i = i + 1
    END FOREACH
    CALL m_lines.deleteElement(i)
    RETURN m_lines.getLength()
END FUNCTION

FUNCTION ord_get_line(p_idx)
    DEFINE p_idx INTEGER
    RETURN m_lines[p_idx].*
END FUNCTION

-- lines of a new order, filled by the screen before ord_create()
FUNCTION ord_clear_new_lines()
    CALL m_new.clear()
END FUNCTION

FUNCTION ord_add_new_line(p_productid, p_unitprice, p_quantity, p_discount)
    DEFINE p_productid LIKE order_details.productid
    DEFINE p_unitprice LIKE order_details.unitprice
    DEFINE p_quantity  LIKE order_details.quantity
    DEFINE p_discount  LIKE order_details.discount
    DEFINE n INTEGER

    LET n = m_new.getLength() + 1
    LET m_new[n].productid = p_productid
    LET m_new[n].unitprice = p_unitprice
    LET m_new[n].quantity  = p_quantity
    LET m_new[n].discount  = p_discount
END FUNCTION

-- header of one order
FUNCTION ord_load_header(p_orderid, p_rec)
    DEFINE p_orderid LIKE orders.orderid
    DEFINE p_rec RECORD LIKE orders.*

    SELECT * INTO p_rec.* FROM orders WHERE orderid = p_orderid
    RETURN sqlca.sqlcode, p_rec.*
END FUNCTION

-- orders placed this year by one customer
FUNCTION ord_count_this_year(p_customerid)
    DEFINE p_customerid LIKE orders.customerid
    DEFINE l_count INTEGER

    SELECT COUNT(*) INTO l_count
      FROM orders
     WHERE customerid = p_customerid
       AND orderdate >= TODAY - 365
    RETURN l_count
END FUNCTION

-- new order: header with the next key, lines, stock moved to "on order"
FUNCTION ord_create(p_rec)
    DEFINE p_rec   RECORD LIKE orders.*
    DEFINE i       INTEGER

    TRY
        BEGIN WORK
        LET p_rec.orderid = nw_next_id("SEQ_NW_ORDERS")
        LET p_rec.orderdate = TODAY
        INSERT INTO orders (orderid, customerid, employeeid, orderdate, requireddate,
                            shipvia, freight, shipname, shipaddress, shipcity,
                            shipregion, shippostalcode, shipcountry)
            VALUES (p_rec.orderid, p_rec.customerid, p_rec.employeeid, p_rec.orderdate,
                    p_rec.requireddate, p_rec.shipvia, p_rec.freight, p_rec.shipname,
                    p_rec.shipaddress, p_rec.shipcity, p_rec.shipregion,
                    p_rec.shippostalcode, p_rec.shipcountry)
        FOR i = 1 TO m_new.getLength()
            INSERT INTO order_details (orderid, productid, unitprice, quantity, discount)
                VALUES (p_rec.orderid, m_new[i].productid, m_new[i].unitprice,
                        m_new[i].quantity, m_new[i].discount)
            UPDATE products
               SET unitsinstock = unitsinstock - m_new[i].quantity,
                   unitsonorder = unitsonorder + m_new[i].quantity
             WHERE productid = m_new[i].productid
        END FOR
        COMMIT WORK
    CATCH
        ROLLBACK WORK
        RETURN sqlca.sqlcode, 0
    END TRY
    RETURN 0, p_rec.orderid
END FUNCTION

-- mark an order as shipped; the row is locked first (lock mode NOT WAIT: no waiting)
FUNCTION ord_ship(p_orderid, p_shipvia)
    DEFINE p_orderid LIKE orders.orderid
    DEFINE p_shipvia LIKE orders.shipvia
    DEFINE l_rowid   INTEGER
    DEFINE l_shipped LIKE orders.shippeddate

    DECLARE c_ship CURSOR FOR
        SELECT ROWID, shippeddate
          FROM orders
         WHERE orderid = p_orderid
           FOR UPDATE
    TRY
        BEGIN WORK
        OPEN c_ship
        FETCH c_ship INTO l_rowid, l_shipped
        IF l_shipped IS NOT NULL THEN
            CLOSE c_ship
            ROLLBACK WORK
            RETURN 1
        END IF
        UPDATE orders SET shippeddate = TODAY, shipvia = p_shipvia
         WHERE ROWID = l_rowid
        CLOSE c_ship
        COMMIT WORK
    CATCH
        ROLLBACK WORK
        RETURN sqlca.sqlcode
    END TRY
    RETURN 0
END FUNCTION

-- bring the line prices of one order back to the catalogue prices
FUNCTION ord_reprice(p_orderid)
    DEFINE p_orderid LIKE orders.orderid

    TRY
        BEGIN WORK
        SQL
            MERGE INTO order_details d
            USING (SELECT productid, unitprice FROM products) p
               ON (d.productid = p.productid AND d.orderid = $p_orderid)
             WHEN MATCHED THEN UPDATE SET d.unitprice = p.unitprice
        END SQL
        COMMIT WORK
    CATCH
        ROLLBACK WORK
        RETURN sqlca.sqlcode
    END TRY
    RETURN 0
END FUNCTION

-- freight surcharge
FUNCTION ord_freight_surcharge(p_orderid, p_pct)
    DEFINE p_orderid LIKE orders.orderid
    DEFINE p_pct     DECIMAL(5,2)
    DEFINE l_factor  DECIMAL(7,4)

    LET l_factor = 1 + p_pct / 100
    PREPARE p_frt FROM "UPDATE orders SET freight = ROUND(freight * ?, 2) WHERE orderid = ?"
    TRY
        BEGIN WORK
        EXECUTE p_frt USING l_factor, p_orderid
        COMMIT WORK
    CATCH
        ROLLBACK WORK
        RETURN sqlca.sqlcode
    END TRY
    FREE p_frt
    RETURN 0
END FUNCTION

-- orders shipped after the required date
FUNCTION ord_late_count()
    DEFINE l_count INTEGER

    SELECT COUNT(*) INTO l_count FROM orders
     WHERE shippeddate > requireddate
    RETURN l_count
END FUNCTION

-- orders shipped more than a week after the required date
FUNCTION ord_very_late_count()
    DEFINE l_count INTEGER

    SELECT COUNT(*) INTO l_count FROM orders
     WHERE shippeddate > requireddate + 7
    RETURN l_count
END FUNCTION

-- payment date of an order: one month after the order date
FUNCTION ord_payment_due(p_orderid)
    DEFINE p_orderid LIKE orders.orderid
    DEFINE l_due     DATE

    SELECT orderdate + 1 UNITS MONTH
      INTO l_due
      FROM orders
     WHERE orderid = p_orderid
    RETURN l_due
END FUNCTION

-- follow-up call one month after shipping; an order shipped on the last day
-- of a month is followed up on the last day of the next month
FUNCTION ord_followup_date(p_orderid)
    DEFINE p_orderid LIKE orders.orderid
    DEFINE l_date    DATE

    PREPARE p_fup FROM
        "SELECT ADD_MONTHS(shippeddate, 1) FROM orders WHERE orderid = ?"
    EXECUTE p_fup USING p_orderid INTO l_date
    FREE p_fup
    RETURN l_date
END FUNCTION

-- open orders due before the end of the coming month
FUNCTION ord_open_due_count(p_ref)
    DEFINE p_ref   DATE
    DEFINE l_count INTEGER
    DEFINE l_first DATE

    LET l_first = MDY(MONTH(p_ref), 1, YEAR(p_ref))
    SELECT COUNT(*) INTO l_count FROM orders
     WHERE shippeddate IS NULL
       AND requireddate < l_first + 2 UNITS MONTH
    RETURN l_count
END FUNCTION

-- shippers for the combobox
FUNCTION ord_fill_shippers(p_cb)
    DEFINE p_cb ui.ComboBox
    DEFINE l_id   LIKE shippers.shipperid
    DEFINE l_name LIKE shippers.companyname

    CALL p_cb.clear()
    DECLARE c_shp CURSOR FOR
        SELECT shipperid, companyname FROM shippers ORDER BY companyname
    FOREACH c_shp INTO l_id, l_name
        CALL p_cb.addItem(l_id, l_name)
    END FOREACH
END FUNCTION
