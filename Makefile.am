NULL = 

SUBDIRS = \
	client \
	data \
	po \
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
	src/ChannelFactory.vala \
	src/ChannelList.vala \
	src/ChannelListReader.vala \
	src/ChannelListWriter.vala \
	src/ConfigStore.vala \
	src/Constants.vala \
	src/Device.vala \
	src/DeviceGroup.vala \
	src/EPGScanner.vala \
	src/EPGStore.vala \
	src/Event.vala \
	src/Factory.vala \
	src/IDBusChannelList.vala \
	src/IDBusDeviceGroup.vala \
	src/IDBusManager.vala \
	src/IDBusRecorder.vala \
	src/IDBusRecordingsStore.vala \
	src/IDBusSchedule.vala \
	src/Main.vala \
	src/Manager.vala \
	src/MpegTsEnums.vala \
	src/OverlapType.vala \
	src/Recorder.vala \
	src/Recording.vala \
	src/RecordingsStore.vala \
	src/Scanner.vala \
	src/ScannedItem.vala \
	src/Schedule.vala \
	src/Settings.vala \
	src/SqliteConfigTimersStore.vala \
	src/SqliteEPGStore.vala \
	src/Timer.vala \
	src/TimersStore.vala \
	src/Utils.vala \
	src/rtsp/MediaFactory.vala \
	src/rtsp/MediaMapping.vala \
	src/rtsp/Server.vala \
	src/rygel/Interfaces.vala \
	src/rygel/Services.vala \
	$(NULL)

vala_pkgs = \
    --pkg gio-2.0 \
    --pkg dbus-glib-1 \
    --pkg gstreamer-0.10 \
    --pkg gee-1.0 \
    --pkg sqlite3 \
    --pkg gst-rtsp-server-0.10
    
own_pkgs = \
	--pkg config \
	--pkg cutils

gnome_dvb_daemon_SOURCES = \
	$(gnome_dvb_daemon_VALASOURCES:.vala=.c) \
	$(NULL)
	
gnome_dvb_daemon_CPPFLAGS = \
	-DPACKAGE_LOCALE_DIR=\""$(prefix)/$(DATADIRNAME)/locale"\" \
	-DPACKAGE_SRC_DIR=\""$(srcdir)"\" \
	-DPACKAGE_DATA_DIR=\""$(datadir)"\" \
	$(GNOME_DVB_DAEMON_CFLAGS) \
	$(GST_CFLAGS) \
	-I$(top_srcdir)/vapi \
	-include $(CONFIG_HEADER) \
	$(NULL)

src/gnome-dvb-daemon.vala.stamp: $(gnome_dvb_daemon_VALASOURCES)
	$(VALAC) -C --thread --vapidir=$(top_srcdir)/vapi $(own_pkgs) $(vala_pkgs) --basedir $(top_srcdir) $^
	touch $@

gnome_dvb_daemon_LDFLAGS = \
	-Wl,--export-dynamic

gnome_dvb_daemon_LDADD = \
	$(GNOME_DVB_DAEMON_LIBS) \
	$(GST_LIBS) \
	libdvbdaemon-utils.a \
	$(NULL)

noinst_LIBRARIES = libdvbdaemon-utils.a
libdvbdaemon_utils_a_SOURCES = \
	vapi/cstuff.c \
	$(NULL)

libdvbdaemon_utils_a_CPPFLAGS = \
	$(GST_CFLAGS) \
	$(NULL)

EXTRA_DIST = \
	intltool-extract.in \
	intltool-update.in \
	intltool-merge.in \
	$(gnome_dvb_daemon_VALASOURCES) \
	src/gnome-dvb-daemon.vala.stamp \
	vapi/config.vapi \
	vapi/cutils.vapi \
	vapi/cstuff.h \
	$(NULL)

DISTCLEANFILES = \
	intltool-extract \
	intltool-update \
	intltool-merge \
	po/.intltool-merge-cache \
	$(NULL)

