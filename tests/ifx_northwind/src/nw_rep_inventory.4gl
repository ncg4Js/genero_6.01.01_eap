-- nw_rep_inventory.4gl: stock and reorder list by supplier country, supplier and category

SCHEMA northwind

TYPE t_stock RECORD
    country      LIKE suppliers.country,
    supplier     LIKE suppliers.companyname,
    categoryname LIKE categories.categoryname,
    productid    LIKE products.productid,
    productname  LIKE products.productname,
    unitprice    LIKE products.unitprice,
    unitsinstock LIKE products.unitsinstock,
    unitsonorder LIKE products.unitsonorder,
    reorderlevel LIKE products.reorderlevel,
    discontinued LIKE products.discontinued,
    sold         INTEGER,
    stockvalue   DECIMAL(12,2),
    flag         CHAR(8)
END RECORD

FUNCTION rep_inventory_run(p_file)
    DEFINE p_file  STRING
    DEFINE l_stock t_stock

    -- quantities sold per product, kept for the main query
    WHENEVER ERROR CONTINUE
    DROP TABLE t_sold
    WHENEVER ERROR STOP
    SELECT productid, SUM(quantity) sold
      FROM order_details
     GROUP BY productid
      INTO TEMP t_sold

    DECLARE c_stock CURSOR FOR
        SELECT s.country, s.companyname, c.categoryname, p.productid, p.productname,
               p.unitprice, p.unitsinstock, p.unitsonorder, p.reorderlevel, p.discontinued,
               t.sold
          FROM products p, suppliers s, OUTER categories c, OUTER t_sold t
         WHERE s.supplierid = p.supplierid
           AND c.categoryid = p.categoryid
           AND t.productid = p.productid

    START REPORT rep_inventory TO FILE p_file
    FOREACH c_stock INTO l_stock.country THRU l_stock.sold
        IF l_stock.sold IS NULL THEN
            LET l_stock.sold = 0
        END IF
        LET l_stock.stockvalue = l_stock.unitprice * l_stock.unitsinstock
        CASE
            WHEN l_stock.discontinued = "Y"
                LET l_stock.flag = "DISCONT"
            WHEN l_stock.unitsinstock + l_stock.unitsonorder <= l_stock.reorderlevel
                LET l_stock.flag = "REORDER"
            WHEN l_stock.unitsinstock = 0
                LET l_stock.flag = "EMPTY"
            OTHERWISE
                LET l_stock.flag = ""
        END CASE
        OUTPUT TO REPORT rep_inventory(l_stock.*)
    END FOREACH
    FINISH REPORT rep_inventory
    FREE c_stock
    DROP TABLE t_sold
END FUNCTION

REPORT rep_inventory(r)
    DEFINE r t_stock

    OUTPUT
        LEFT MARGIN 2
        TOP MARGIN 0
        BOTTOM MARGIN 0
        PAGE LENGTH 66

    -- the report sorts the rows itself
    ORDER BY r.country, r.supplier, r.categoryname, r.productname

    FORMAT
        FIRST PAGE HEADER
            PRINT "NORTHWIND TRADERS - STOCK AND REORDER LIST"
            PRINT "Printed ", TODAY USING "yyyy-mm-dd", " at ", TIME
            PRINT "Flags: REORDER = stock + on order at or below the reorder level"
            SKIP 1 LINE

        PAGE HEADER
            PRINT "STOCK AND REORDER LIST (continued)", COLUMN 70, "Page ", PAGENO USING "<<&"
            SKIP 1 LINE

        BEFORE GROUP OF r.country
            NEED 6 LINES
            PRINT "=== ", r.country CLIPPED, " ======================================"

        BEFORE GROUP OF r.supplier
            NEED 4 LINES
            PRINT COLUMN 3, r.supplier CLIPPED

        BEFORE GROUP OF r.categoryname
            PRINT COLUMN 5, "[", r.categoryname CLIPPED, "]"

        ON EVERY ROW
            PRINT COLUMN 7, r.productid USING "##&",
                  COLUMN 12, r.productname[1,28],
                  COLUMN 41, r.unitsinstock USING "##&",
                  COLUMN 46, r.unitsonorder USING "##&",
                  COLUMN 51, r.reorderlevel USING "##&",
                  COLUMN 56, r.sold USING "#,##&",
                  COLUMN 63, r.stockvalue USING "##,##&.&&",
                  COLUMN 74, r.flag CLIPPED

        AFTER GROUP OF r.supplier
            PRINT COLUMN 5, "Supplier stock value",
                  COLUMN 61, GROUP SUM(r.stockvalue) USING "####,##&.&&",
                  COLUMN 74, GROUP COUNT(*) WHERE r.flag = "REORDER" USING "<&", " to reorder"

        AFTER GROUP OF r.country
            SKIP 1 LINE
            PRINT COLUMN 3, r.country CLIPPED, ": ",
                  GROUP COUNT(*) USING "<<&", " products, ",
                  GROUP COUNT(*) WHERE r.discontinued = "Y" USING "<&", " discontinued",
                  COLUMN 59, GROUP SUM(r.stockvalue) USING "##,###,##&.&&"
            SKIP 1 LINE

        ON LAST ROW
            NEED 5 LINES
            PRINT "=================================================================================="
            PRINT "Products        ", COUNT(*) USING "<<<&"
            PRINT "To reorder      ", COUNT(*) WHERE r.flag = "REORDER" USING "<<<&"
            PRINT "Units sold      ", SUM(r.sold) USING "<<<,<<&"
            PRINT "Stock value     ", SUM(r.stockvalue) USING "<<<,<<<,<<&.&&",
                  "   (", SUM(r.stockvalue) WHERE r.flag = "REORDER" USING "<<<,<<&.&&", " in products to reorder)"
END REPORT
