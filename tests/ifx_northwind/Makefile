# Build file. Modules go to bin/. Needs FGLDBPATH to find schema/northwind.sch
export FGLDBPATH=$(CURDIR)/schema

ORD_MODS  = nw_orders nw_orders_db nw_common
CAT_MODS  = nw_catalog nw_catalog_db nw_common
STF_MODS  = nw_staff nw_staff_db nw_common
CUS_MODS  = nw_customers nw_customers_db nw_common
REP_MODS  = nw_reports nw_rep_sales nw_rep_inventory nw_rep_statement nw_common
FORMS     = nw_orders nw_catalog nw_staff nw_customers

m = $(addprefix bin/,$(addsuffix .42m,$(1)))
f = $(addprefix bin/,$(addsuffix .42f,$(1)))

all: bin/nw_orders.42r bin/nw_catalog.42r bin/nw_staff.42r bin/nw_customers.42r bin/nw_reports.42r $(call f,$(FORMS))

bin/%.42m: src/%.4gl
	cd bin && fglcomp ../$<

bin/%.42f: src/%.per
	fglform -o bin $<

bin/nw_orders.42r: $(call m,$(ORD_MODS))
	cd bin && fgllink -o nw_orders.42r $(addsuffix .42m,$(ORD_MODS))

bin/nw_catalog.42r: $(call m,$(CAT_MODS))
	cd bin && fgllink -o nw_catalog.42r $(addsuffix .42m,$(CAT_MODS))

bin/nw_staff.42r: $(call m,$(STF_MODS))
	cd bin && fgllink -o nw_staff.42r $(addsuffix .42m,$(STF_MODS))

bin/nw_customers.42r: $(call m,$(CUS_MODS))
	cd bin && fgllink -o nw_customers.42r $(addsuffix .42m,$(CUS_MODS))

bin/nw_reports.42r: $(call m,$(REP_MODS))
	cd bin && fgllink -o nw_reports.42r $(addsuffix .42m,$(REP_MODS))

clean:
	rm -f bin/*.42m bin/*.42f bin/*.42r
