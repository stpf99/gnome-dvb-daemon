ext_LTLIBRARIES =  \
	libgrldvbdaemon.la

libgrldvbdaemon_la_SOURCES =  \
	grl-dvb-daemon-exporter.c \
	grl-dvb-daemon-exporter.h \
	grl-dvb-daemon-source.c \
	grl-dvb-daemon-source.h \
	gdd-channel-list.c \
	gdd-channel-list.h \
	gdd-device-group.c \
	gdd-device-group.h \
	gdd-manager.c \
	gdd-manager.h

libgrldvbdaemon_la_CFLAGS = \
	$(GRILO_CFLAGS) \
	-DG_LOG_DOMAIN=\"GrlDvbDaemon\" \
	-DLOCALEDIR=\"$(localedir)\"

libgrldvbdaemon_la_LIBADD = $(GRILO_LIBS)

libgrldvbdaemon_la_LDFLAGS = \
	-no-undefined	     \
	-module		     \
	-avoid-version

extdir = $(GRL_PLUGINS_DIR)
dvbdaemonxmldir	= $(GRL_PLUGINS_DIR)
dvbdaemonxml_DATA = $(DVBDAEMON_PLUGIN_ID).xml

EXTRA_DIST = $(dvbdaemonxml_DATA)
