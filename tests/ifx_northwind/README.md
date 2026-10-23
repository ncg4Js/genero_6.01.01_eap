# ifx_northwind_test

Northwind order desk: four screen programs and three batch reports.
Genero BDL 6.00.02. Database: Informix 14.10, database `northwind` on server `informix`, reached as `northwind`.

1. `fglprofile` holds the connection entries (driver `dbmifx_9`, Informix CSDK 4.50); user and password come from `NW_USER` and `NW_PASSWORD`. `setenv.sh` sets the environment.
2. `schema/northwind.sch` was extracted from the database with fgldbsch.
3. `make` builds five programs:
   - `nw_orders`: order desk (search, lines, ship, reprice, freight surcharge, copy as new order)
   - `nw_catalog`: products, categories, suppliers, price changes
   - `nw_staff`: management tree, sales per employee, territories
   - `nw_customers`: customers, countries, new customer
   - `nw_reports`: batch reports
     - `fglrun nw_reports sales <file> [yyyy-mm-dd] [months]`: sales by employee, year, month and order
     - `fglrun nw_reports inventory <file>`: stock and reorder list by country, supplier and category
     - `fglrun nw_reports statement <file> [country pattern] [yyyy-mm-dd]`: customer statements
