NULL = 

AUTOMAKE_OPTIONS = subdir-objects

SUBDIRS = \
	client \
	data \
	po \
	$(NULL)
	
AM_CPPFLAGS = \
	-DPACKAGE_LOCALE_DIR=\""$(prefix)/$(DATADIRNAME)/locale"\" \
	-DPACKAGE_SRC_DIR=\""$(srcdir)"\" \
	-DPACKAGE_DATA_DIR=\""$(datadir)"\" \
	$(GNOME_DVB_DAEMON_CFLAGS) \
	-include $(CONFIG_HEADER) \
	$(NULL)

BUILT_SOURCES = \
	src/gnome-dvb-daemon.vala.stamp
	$(NULL)

bin_PROGRAMS = gnome-dvb-daemon

gnome_dvb_daemon_VALASOURCES = \
	src/Cable/CableChannel.vala \
	src/Cable/CableScanner.vala \
	src/Satellite/SatelliteChannel.vala \
	src/Satellite/SatelliteScanner.vala \
	src/Terrestrial/TerrestrialChannel.vala \
	src/Terrestrial/TerrestrialScanner.vala \
	src/ChangeType.vala \
	src/Channel.vala \
	src/ChannelList.vala \
	src/ChannelListReader.vala \
	src/ChannelListWriter.vala \
	src/Constants.vala \
	src/Device.vala \
	src/DeviceGroup.vala \
	src/EPGScanner.vala \
	src/EPGStore.vala \
	src/Event.vala \
	src/GConfStore.vala \
	src/IDBusChannelList.vala \
	src/IDBusRecorder.vala \
	src/IDBusRecordingsStore.vala \
	src/Main.vala \
	src/Manager.vala \
	src/MpegTsEnums.vala \
	src/Recorder.vala \
	src/Recording.vala \
	src/RecordingsStore.vala \
	src/Scanner.vala \
	src/ScannedItem.vala \
	src/Schedule.vala \
	src/Timer.vala \
	src/Utils.vala \
	$(NULL)

gnome_dvb_daemon_SOURCES = \
	$(gnome_dvb_daemon_VALASOURCES:.vala=.c) \
	$(gnome_dvb_daemon_VALASOURCES:.vala=.h) \
	$(NULL)

vala_pkgs = \
    --pkg gio-2.0 \
    --pkg dbus-glib-1 \
    --pkg gstreamer-0.10 \
    --pkg gee-1.0 \
    --pkg gconf-2.0

src/gnome-dvb-daemon.vala.stamp: $(gnome_dvb_daemon_VALASOURCES)
	$(VALAC) -C --thread --vapidir=$(top_srcdir)/vapi --pkg config $(vala_pkgs) --basedir $(top_srcdir) $^
	touch $@

gnome_dvb_daemon_LDFLAGS = \
	-Wl,--export-dynamic

gnome_dvb_daemon_LDADD = \
	$(GNOME_DVB_DAEMON_LIBS) \
	$(NULL)

EXTRA_DIST = \
	intltool-extract.in \
	intltool-update.in \
	intltool-merge.in \
	$(gnome_dvb_daemon_VALASOURCES) \
	src/gnome-dvb-daemon.vala.stamp \
	$(NULL)

DISTCLEANFILES = \
	intltool-extract \
	intltool-update \
	intltool-merge \
	po/.intltool-merge-cache \
	$(NULL)

