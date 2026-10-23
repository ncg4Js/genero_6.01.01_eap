-- nw_staff_db.4gl: SQL for employees, territories and regions

SCHEMA northwind

TYPE t_node RECORD
    lvl        INTEGER,
    employeeid LIKE employees.employeeid,
    fullname   VARCHAR(60),
    title      LIKE employees.title,
    path       VARCHAR(200)
END RECORD

DEFINE m_tree DYNAMIC ARRAY OF t_node
DEFINE m_sales DYNAMIC ARRAY OF RECORD
    employeeid LIKE employees.employeeid,
    lastname   LIKE employees.lastname,
    norders    INTEGER,
    freight    DECIMAL(12,2),
    years      DECIMAL(5,1)
END RECORD

-- management tree, from the top manager down
FUNCTION stf_load_tree()
    DEFINE i INTEGER
    DEFINE l_node t_node

    CALL m_tree.clear()
    DECLARE c_tree CURSOR FOR SQL
        SELECT LEVEL, employeeid,
               LPAD(' ', 2 * (LEVEL - 1)) || NVL(firstname, '') || ' ' || NVL(lastname, ''),
               title,
               SYS_CONNECT_BY_PATH(lastname, '/')
          FROM employees
         START WITH reportsto IS NULL
       CONNECT BY PRIOR employeeid = reportsto
         ORDER SIBLINGS BY lastname
    END SQL
    LET i = 0
    FOREACH c_tree INTO l_node.*
        LET i = i + 1
        LET m_tree[i].* = l_node.*
    END FOREACH
    RETURN i
END FUNCTION

FUNCTION stf_get_node(p_idx)
    DEFINE p_idx INTEGER
    RETURN m_tree[p_idx].*
END FUNCTION

-- orders and freight per employee, with years of service
FUNCTION stf_load_sales()
    DEFINE i INTEGER

    WHENEVER ERROR CONTINUE
    DROP TABLE t_emp_sales
    WHENEVER ERROR STOP

    SELECT employeeid, COUNT(*) norders, SUM(freight) freight
      FROM orders
     GROUP BY employeeid
      INTO TEMP t_emp_sales

    CALL m_sales.clear()
    DECLARE c_sales CURSOR FROM
        "SELECT e.employeeid, e.lastname, NVL(t.norders, 0), NVL(t.freight, 0),"
        || " ROUND(MONTHS_BETWEEN(SYSDATE, e.hiredate) / 12, 1)"
        || " FROM employees e LEFT OUTER JOIN t_emp_sales t ON t.employeeid = e.employeeid"
        || " ORDER BY 3 DESC"
    LET i = 1
    FOREACH c_sales INTO m_sales[i].*
        LET i = i + 1
    END FOREACH
    CALL m_sales.deleteElement(i)
    FREE c_sales
    DROP TABLE t_emp_sales
    RETURN m_sales.getLength()
END FUNCTION

FUNCTION stf_get_sales(p_idx)
    DEFINE p_idx INTEGER
    RETURN m_sales[p_idx].*
END FUNCTION

-- territories of one employee, with their region
FUNCTION stf_territories(p_employeeid)
    DEFINE p_employeeid LIKE employees.employeeid
    DEFINE l_desc   LIKE territories.territorydescription
    DEFINE l_region LIKE region.regiondescription
    DEFINE l_text   STRING

    LET l_text = ""
    DECLARE c_terr CURSOR FOR
        SELECT t.territorydescription, r.regiondescription
          FROM employee_territories et, territories t, OUTER region r
         WHERE et.employeeid = p_employeeid
           AND t.territoryid = et.territoryid
           AND r.regionid = t.regionid
         ORDER BY 1
    FOREACH c_terr INTO l_desc, l_region
        LET l_text = l_text, l_desc CLIPPED, " (", l_region CLIPPED, ")\n"
    END FOREACH
    IF l_text.getLength() = 0 THEN
        LET l_text = "No territory assigned"
    END IF
    RETURN l_text
END FUNCTION

-- employees with a work anniversary in the coming month
FUNCTION stf_anniversaries()
    DEFINE l_count INTEGER

    PREPARE p_ann FROM
        "SELECT COUNT(*) FROM employees"
        || " WHERE MONTH(hiredate) = MONTH(ADD_MONTHS(TODAY, 1))"
    EXECUTE p_ann INTO l_count
    FREE p_ann
    RETURN l_count
END FUNCTION

-- employees hired before a date, Informix style
FUNCTION stf_hired_before(p_date)
    DEFINE p_date DATE
    DEFINE l_count INTEGER

    SELECT COUNT(*) INTO l_count FROM employees
     WHERE hiredate < p_date
       AND birthdate IS NOT NULL
       AND lastname MATCHES "*o*"
    RETURN l_count
END FUNCTION

-- employees who reach five years of service within a year of a date
FUNCTION stf_five_years_by(p_date)
    DEFINE p_date  DATE
    DEFINE l_count INTEGER

    SELECT COUNT(*) INTO l_count FROM employees
     WHERE hiredate + 5 UNITS YEAR >= p_date
       AND hiredate + 5 UNITS YEAR < p_date + 1 UNITS YEAR
    RETURN l_count
END FUNCTION

-- age of an employee today
FUNCTION stf_age(p_employeeid)
    DEFINE p_employeeid LIKE employees.employeeid
    DEFINE l_birth LIKE employees.birthdate
    DEFINE l_age INTEGER

    SELECT birthdate INTO l_birth FROM employees WHERE employeeid = p_employeeid
    IF l_birth IS NULL THEN
        RETURN NULL
    END IF
    LET l_age = YEAR(TODAY) - YEAR(l_birth)
    IF MDY(MONTH(l_birth), DAY(l_birth), YEAR(TODAY)) > TODAY THEN
        LET l_age = l_age - 1
    END IF
    RETURN l_age
END FUNCTION
