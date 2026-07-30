TOOL=darktable-chart

STYLES=astia provia velvia classic-chrome monochrome reference

.PHONY: all styles-lo styles-hi clean
all: styles-lo styles-hi

styles-lo: $(patsubst %,%-lo.dtstyle,$(STYLES))
styles-hi: $(patsubst %,%-hi.dtstyle,$(STYLES))

%-lo.dtstyle: %.csv Makefile
	$(TOOL) --csv $< 24 $@

%-hi.dtstyle: %-49.csv Makefile
	$(TOOL) --csv $< 49 $@

clean:
	rm -f $(patsubst %,%-lo.dtstyle,$(STYLES))
	rm -f $(patsubst %,%-hi.dtstyle,$(STYLES))
