-- nw_reports.4gl: batch printing of the Northwind reports
--   fglrun nw_reports sales     <file> [reference date yyyy-mm-dd] [months back]
--   fglrun nw_reports inventory <file>
--   fglrun nw_reports statement <file> [country pattern] [from date yyyy-mm-dd]

MAIN
    DEFINE l_which, l_file STRING
    DEFINE l_ref DATE
    DEFINE l_months INTEGER
    DEFINE l_country VARCHAR(15)
    DEFINE l_from DATE

    LET l_which = arg_val(1)
    LET l_file = arg_val(2)
    IF l_file IS NULL THEN
        LET l_file = l_which, ".txt"
    END IF

    CALL nw_connect()
    SET ISOLATION TO DIRTY READ

    CASE l_which
        WHEN "sales"
            LET l_ref = parse_date(arg_val(3), MDY(5, 31, 1998))
            LET l_months = arg_val(4)
            IF l_months IS NULL OR l_months <= 0 THEN
                LET l_months = 12
            END IF
            CALL rep_sales_run(l_file, l_ref, l_months)
        WHEN "inventory"
            CALL rep_inventory_run(l_file)
        WHEN "statement"
            LET l_country = arg_val(3)
            IF l_country IS NULL THEN
                LET l_country = "*"
            END IF
            LET l_from = parse_date(arg_val(4), MDY(1, 1, 1998))
            CALL rep_statement_run(l_file, l_country, l_from)
        OTHERWISE
            DISPLAY "Usage: nw_reports sales|inventory|statement <file> [options]"
            EXIT PROGRAM 1
    END CASE

    CALL nw_disconnect()
    DISPLAY "Report written to ", l_file
END MAIN

-- yyyy-mm-dd text to DATE, with a default
FUNCTION parse_date(p_text, p_default)
    DEFINE p_text STRING
    DEFINE p_default DATE

    IF p_text IS NULL OR p_text.getLength() != 10 THEN
        RETURN p_default
    END IF
    RETURN MDY(p_text.subString(6, 7), p_text.subString(9, 10), p_text.subString(1, 4))
END FUNCTION
