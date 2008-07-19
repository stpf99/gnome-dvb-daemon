# sample python plugin
plugindir = $(PLUGINDIR)
#plugin_PYTHON = dvb-rhythm.py

plugin_in_files = dvb-rhythm.rb-plugin.in
%.rb-plugin: %.rb-plugin.in $(INTLTOOL_MERGE) $(wildcard $(top_srcdir)/po/*po) ; $(INTLTOOL_MERGE) $(top_srcdir)/po $< $@ -d -u -c $(top_builddir)/po/.intltool-merge-cache

#plugin_DATA = $(plugin_in_files:.rb-plugin.in=.rb-plugin)

EXTRA_DIST = $(plugin_in_files) dvb-rhythm.py

CLEANFILES = $(plugin_DATA)
DISTCLEANFILES = $(plugin_DATA)
