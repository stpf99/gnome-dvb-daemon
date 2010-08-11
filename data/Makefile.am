SUBDIRS = icons

desktopdir = $(datadir)/applications
desktop_in_files = \
	gnome-dvb-control.desktop.in \
	gnome-dvb-setup.desktop.in \
	$(NULL)
desktop_DATA = $(desktop_in_files:.desktop.in=.desktop)
@INTLTOOL_DESKTOP_RULE@

# Dbus service file
dbusservicedir = $(DBUS_SERVICES_DIR)
dbusservice_in_files = \
	org.gnome.DVB.service.in \
	org.gnome.UPnP.MediaServer1.DVBDaemon.service.in \
	org.gnome.UPnP.MediaServer2.DVBDaemon.service.in
dbusservice_DATA = $(dbusservice_in_files:.service.in=.service)

# Rule to make the service file with bindir expanded
$(dbusservice_DATA): %.service: %.service.in
	$(AM_V_at)sed -e "s|\@bindir\@|$(bindir)|" $< > $@

CLEANFILES = \
	$(dbusservice_DATA) \
	$(desktop_DATA)	

EXTRA_DIST = \
	$(dbusservice_in_files) \
	$(desktop_in_files) \
	$(desktop_DATA)	
