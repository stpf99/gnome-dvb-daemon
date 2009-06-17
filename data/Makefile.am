# Dbus service file
dbusservicedir = $(DBUS_SERVICES_DIR)
dbusservice_in_files = \
	org.gnome.DVB.service.in \
	org.gnome.UPnP.MediaServer1.DVBDaemon.service.in
dbusservice_DATA = $(dbusservice_in_files:.service.in=.service)

# Rule to make the service file with bindir expanded
#$(dbusservice_DATA): $(dbusservice_in_files) Makefile
$(dbusservice_DATA): %.service: %.service.in
	sed -e "s|\@bindir\@|$(bindir)|" $< > $@

CLEANFILES = $(dbusservice_DATA)
EXTRA_DIST = $(dbusservice_in_files)
