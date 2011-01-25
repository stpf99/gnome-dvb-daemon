plugindir = $(TOTEM_PLUGIN_DIR)/dvb-daemon
plugin_PYTHON = dvb-daemon.py

plugin_in_files = dvb-daemon.plugin.in

%.plugin: %.plugin.in $(INTLTOOL_MERGE) $(wildcard $(top_srcdir)/po/*po) ; $(INTLTOOL_MERGE) $(top_srcdir)/po $< $@ -d -u -c $(top_builddir)/po/.intltool-merge-cache

plugin_DATA = $(plugin_in_files:.plugin.in=.plugin)

EXTRA_DIST = $(plugin_in_files) dvb-daemon.py

CLEANFILES = $(plugin_DATA)
DISTCLEANFILES = $(plugin_DATA) 
