-- nw_catalog_db.4gl: SQL for products, categories and suppliers

SCHEMA northwind

TYPE t_product RECORD
    productid    LIKE products.productid,
    productname  LIKE products.productname,
    categoryname LIKE categories.categoryname,
    supplier     LIKE suppliers.companyname,
    unitprice    LIKE products.unitprice,
    unitsinstock LIKE products.unitsinstock,
    status       VARCHAR(12)
END RECORD

DEFINE m_products DYNAMIC ARRAY OF t_product
DEFINE m_top DYNAMIC ARRAY OF RECORD
           productname LIKE products.productname,
           unitprice   LIKE products.unitprice
       END RECORD

-- products matching a CONSTRUCT condition, with their category and supplier
FUNCTION cat_search(p_where)
    DEFINE p_where STRING
    DEFINE l_sql   STRING
    DEFINE i       INTEGER

    LET l_sql = "SELECT products.productid, products.productname, categories.categoryname,",
                "       suppliers.companyname, products.unitprice, products.unitsinstock,",
                "       NVL2(NULLIF(products.discontinued, 'N'), 'discontinued',",
                "            DECODE(SIGN(products.unitsinstock + products.unitsonorder - products.reorderlevel),",
                "                   -1, 'reorder', 0, 'reorder', 'ok'))",
                "  FROM products, OUTER categories, OUTER suppliers",
                " WHERE products.categoryid = categories.categoryid",
                "   AND products.supplierid = suppliers.supplierid",
                "   AND ", p_where,
                " ORDER BY categories.categoryname NULLS LAST, products.productname"
    CALL m_products.clear()
    DECLARE c_prod CURSOR FROM l_sql
    LET i = 1
    FOREACH c_prod INTO m_products[i].*
        LET i = i + 1
    END FOREACH
    CALL m_products.deleteElement(i)
    FREE c_prod
    RETURN m_products.getLength()
END FUNCTION

FUNCTION cat_get_row(p_idx)
    DEFINE p_idx INTEGER
    RETURN m_products[p_idx].*
END FUNCTION

-- products whose name matches a pattern (* and ?), Informix style
FUNCTION cat_count_by_name(p_pattern)
    DEFINE p_pattern VARCHAR(40)
    DEFINE l_count INTEGER

    PREPARE p_byname FROM
        "SELECT COUNT(*) FROM products p, OUTER categories c"
        || " WHERE p.categoryid = c.categoryid"
        || "   AND p.productname MATCHES '" || p_pattern CLIPPED || "'"
    EXECUTE p_byname INTO l_count
    FREE p_byname
    RETURN l_count
END FUNCTION

-- products whose name starts with the same three letters
FUNCTION cat_same_prefix(p_name)
    DEFINE p_name  LIKE products.productname
    DEFINE l_count INTEGER
    DEFINE l_prefix CHAR(3)

    LET l_prefix = p_name
    SELECT COUNT(*) INTO l_count FROM products
     WHERE productname[1,3] = l_prefix
    RETURN l_count
END FUNCTION

-- the ten most expensive products
FUNCTION cat_top_prices()
    DEFINE i INTEGER

    CALL m_top.clear()
    DECLARE c_top CURSOR FROM
        "SELECT FIRST 10 productname, unitprice FROM products ORDER BY unitprice DESC"
    LET i = 1
    FOREACH c_top INTO m_top[i].*
        LET i = i + 1
    END FOREACH
    CALL m_top.deleteElement(i)
    FREE c_top
    RETURN m_top.getLength()
END FUNCTION

FUNCTION cat_get_top(p_idx)
    DEFINE p_idx INTEGER
    RETURN m_top[p_idx].*
END FUNCTION

-- products whose name starts with a letter of the range
FUNCTION cat_count_range(p_from, p_to)
    DEFINE p_from, p_to CHAR(1)
    DEFINE l_count INTEGER
    DEFINE l_pattern VARCHAR(20)

    LET l_pattern = "[", p_from, "-", p_to, "]*"
    PREPARE p_rng FROM "SELECT COUNT(*) FROM products WHERE productname MATCHES ?"
    EXECUTE p_rng USING l_pattern INTO l_count
    FREE p_rng
    RETURN l_count
END FUNCTION

-- price change for one category, in percent
FUNCTION cat_change_prices(p_categoryid, p_pct)
    DEFINE p_categoryid LIKE products.categoryid
    DEFINE p_pct DECIMAL(5,2)

    TRY
        BEGIN WORK
        UPDATE products
           SET unitprice = ROUND(unitprice * (1 + p_pct / 100), 2)
         WHERE categoryid = p_categoryid
           AND discontinued = "N"
        COMMIT WORK
    CATCH
        ROLLBACK WORK
        RETURN sqlca.sqlcode, 0
    END TRY
    RETURN 0, sqlca.sqlerrd[3]
END FUNCTION

-- suppliers without any active product
FUNCTION cat_idle_suppliers()
    DEFINE l_count INTEGER

    SELECT COUNT(*) INTO l_count FROM suppliers s
     WHERE NOT EXISTS (SELECT 1 FROM products p
                        WHERE p.supplierid = s.supplierid
                          AND p.discontinued = "N")
    RETURN l_count
END FUNCTION

FUNCTION cat_fill_categories(p_cb)
    DEFINE p_cb ui.ComboBox
    DEFINE l_id   LIKE categories.categoryid
    DEFINE l_name LIKE categories.categoryname

    CALL p_cb.clear()
    DECLARE c_cat CURSOR FOR
        SELECT categoryid, categoryname FROM categories ORDER BY categoryname
    FOREACH c_cat INTO l_id, l_name
        CALL p_cb.addItem(l_id, l_name)
    END FOREACH
END FUNCTION
