NULL = 

AUTOMAKE_OPTIONS = subdir-objects

SUBDIRS = \
	data \
	po \
	$(NULL)
	
AM_CPPFLAGS = \
	-DPACKAGE_LOCALE_DIR=\""$(prefix)/$(DATADIRNAME)/locale"\" \
	-DPACKAGE_SRC_DIR=\""$(srcdir)"\" \
	-DPACKAGE_DATA_DIR=\""$(datadir)"\" \
	$(DVB_DAEMON_CFLAGS) \
	-include $(CONFIG_HEADER) \
	$(NULL)

BUILT_SOURCES = \
	src/dvb-daemon.vala.stamp
	$(NULL)

bin_PROGRAMS = dvb-daemon

dvb_daemon_VALASOURCES = \
	src/Scanner/Scanner.vala \
	src/Scanner/CableScanner.vala \
	src/Scanner/SatelliteScanner.vala \
	src/Scanner/TerrestrialScanner.vala \
	src/Scanner/ScannedItem.vala \
	src/Scanner/ChannelListWriter.vala \
	src/Main.vala \
	src/Device.vala \	
	src/MpegTsEnums.vala \
	src/Channel.vala \
	src/Manager.vala \
	src/Constants.vala \
	src/Recorder.vala \
	src/Utils.vala \
	$(NULL)

dvb_daemon_SOURCES = \
	$(dvb_daemon_VALASOURCES:.vala=.c) \
	$(dvb_daemon_VALASOURCES:.vala=.h) \
	$(NULL)

vala_pkgs = \
	--pkg gio-2.0 \
    --pkg dbus-glib-1 \
    --pkg gstreamer-0.10 \
    --pkg gee-1.0 

src/dvb-daemon.vala.stamp: $(dvb_daemon_VALASOURCES)
	$(VALAC) -C $(vala_pkgs) --basedir $(top_srcdir) $^
	touch $@

dvb_daemon_LDFLAGS = \
	-Wl,--export-dynamic

dvb_daemon_LDADD = \
	$(DVB_DAEMON_LIBS) \
	$(NULL)

EXTRA_DIST = \
	intltool-extract.in \
	intltool-update.in \
	intltool-merge.in \
	$(dvb_daemon_VALASOURCES) \
	src/dvb-daemon.vala.stamp \
	$(NULL)

DISTCLEANFILES = \
	intltool-extract \
	intltool-update \
	intltool-merge \
	po/.intltool-merge-cache \
	$(NULL)

