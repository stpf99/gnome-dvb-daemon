AC_PREREQ(2.63.2)
AC_INIT([gnome-dvb-daemon], [0.1.23],
       [https://bugs.launchpad.net/gnome-dvb-daemon],
       [gnome-dvb-daemon],
       [http://live.gnome.org/DVBDaemon])
AC_CONFIG_SRCDIR([Makefile.am])
AC_CONFIG_HEADERS(config.h)
AC_CONFIG_MACRO_DIR([m4])
AM_INIT_AUTOMAKE([1.11 subdir-objects dist-bzip2])
AM_MAINTAINER_MODE
m4_ifdef([AM_SILENT_RULES],[AM_SILENT_RULES([yes])])

AC_PROG_CC
AM_PROG_CC_C_O

LT_PREREQ([2.2.6])
LT_INIT([disable-static])

AM_PROG_VALAC([0.10.0])

AH_TEMPLATE([GETTEXT_PACKAGE], [gnome-dvb-daemon])
GETTEXT_PACKAGE=gnome-dvb-daemon
AC_DEFINE_UNQUOTED(GETTEXT_PACKAGE, "$GETTEXT_PACKAGE")
AC_SUBST(GETTEXT_PACKAGE)
AM_GLIB_GNU_GETTEXT
IT_PROG_INTLTOOL([0.40.0])

AC_SUBST(CFLAGS)
AC_SUBST(CPPFLAGS)
AC_SUBST(LDFLAGS)

dnl *********************
dnl * time.h and timegm
dnl *********************
AC_CHECK_HEADERS([time.h], have_time=yes, have_time=no)
if test "x$have_time" = "xno"; then
	AC_MSG_ERROR([Could not find time.h])
fi

AC_CHECK_FUNC([timegm], have_timegm=yes, have_timegm=no)
if test "x$have_timegm" = "xno"; then
	AC_MSG_ERROR([Could not find timegm function])
fi

dnl ***********
dnl * signal.h
dnl ***********
AC_CHECK_HEADERS([signal.h], have_signal=yes, have_signal=no)
if test "x$have_signal" = "xno"; then
	AC_MSG_ERROR([Could not find signal.h])
fi

dnl ******************
dnl * Check for libs
dnl ******************
GLIB_REQUIRED=2.16.0
GIO_REQUIRED=2.16.0
GST_REQUIRED=0.10.29
DBUS_REQUIRED=0.74
GEE_REQUIRED=0.5.0
SQLITE_REQUIRED=3.4
GST_RTSP_SERVER_REQUIRED=0.10.7

PKG_CHECK_MODULES(GST, gstreamer-0.10 >= $GST_REQUIRED
                       gstreamer-rtsp-0.10 >= $GST_REQUIRED)
AC_SUBST(GST_CFLAGS)
AC_SUBST(GST_LIBS)

PKG_CHECK_MODULES(GNOME_DVB_DAEMON, glib-2.0 >= $GLIB_REQUIRED
                            gio-2.0 >= $GIO_REQUIRED
                            gobject-2.0 >= $GLIB_REQUIRED
                            dbus-glib-1 >= $DBUS_REQUIRED
                            gee-1.0 >= $GEE_REQUIRED
                            sqlite3 >= $SQLITE_REQUIRED
                            gst-rtsp-server-0.10 >= $GST_RTSP_SERVER_REQUIRED)
AC_SUBST(GNOME_DVB_DAEMON_CFLAGS)
AC_SUBST(GNOME_DVB_DAEMON_LIBS)

PKG_CHECK_MODULES(GLIB, glib-2.0 >= $GLIB_REQUIRED)
AC_SUBST(GLIB_CFLAGS)
AC_SUBST(GLIB_LIBS)

PKG_CHECK_MODULES(GUDEV, gudev-1.0)
AC_SUBST(GUDEV_CFLAGS)
AC_SUBST(GUDEV_LIBS)

AG_GST_CHECK_GST_INSPECT
AG_GST_CHECK_MODULE_BAD([mpegtsparse])
AG_GST_CHECK_MODULE_BAD([dvbbasebin])
AG_GST_CHECK_MODULE_BAD([dvbsrc])
AG_GST_CHECK_MODULE_GOOD([rtpmp2tpay])

dnl ****************
dnl * Totem plugin
dnl ****************
AC_ARG_ENABLE([totem-plugin],
	AS_HELP_STRING([--enable-totem-plugin], [Install the Totem plugin]),
	enable_totem="yes",
	enable_totem="no")
	
AM_CONDITIONAL(ENABLE_TOTEM, test "x$enable_totem" = "xyes")

AC_ARG_WITH([totem-plugin-dir],
	AS_HELP_STRING([--with-totem-plugin-dir],
		[Directory where Totem plugins are installed (default: LIBDIR/totem/plugins)]))

if test "x$enable_totem" = "xyes"; then		
	if test "x$with_totem_plugin_dir" = "x"; then
		TOTEM_PLUGIN_DIR="$libdir/totem/plugins"
	else
		TOTEM_PLUGIN_DIR="$with_totem_plugin_dir"
	fi
fi
AC_SUBST(TOTEM_PLUGIN_DIR)

dnl **************
dnl * Expansions
dnl **************
SHAMROCK_EXPAND_DATADIR
SHAMROCK_EXPAND_LIBDIR

dnl *************************************
dnl * Check for DBUS Services directory
dnl *************************************
DBUS_REQUIRED_VERSION=1.1
PKG_CHECK_MODULES(DBUS, dbus-1 >= $DBUS_REQUIRED_VERSION)
DBUS_SERVICES_DIR="$expanded_datadir/dbus-1/services"
AC_SUBST(DBUS_SERVICES_DIR)
AC_DEFINE_UNQUOTED(DBUS_SERVICES_DIR, "$DBUS_SERVICES_DIR", [DBus services directory])

dnl **********
dnl * Python
dnl **********
PYTHON_REQUIRED=2.5
AM_PATH_PYTHON($PYTHON_REQUIRED)
AM_CHECK_PYTHON_HEADERS(,[AC_MSG_ERROR(could not find Python headers)])

AS_AC_EXPAND(DATADIR, $datarootdir)
AC_SUBST(DATADIR)

AS_AC_EXPAND(LIBDIR, $libdir)
AC_SUBST(LIBDIR)

AS_AC_EXPAND(PYTHONDIR, $pythondir)
AC_SUBST(PYTHONDIR)

dnl ******************
dnl * Python modules
dnl *****************
AM_CHECK_PYMOD(glib)
AM_CHECK_PYMOD(gobject)
AM_CHECK_PYMOD(gtk)
AM_CHECK_PYMOD(dbus)
AM_CHECK_PYMOD(gio)
AM_CHECK_PYMOD(gst)

AC_CONFIG_FILES([
	Makefile
	client/Makefile
	client/gnomedvb/defs.py
	client/gnomedvb/Makefile
	client/totem-plugin/Makefile
	data/Makefile
	data/gnome-dvb-control.desktop.in
	data/gnome-dvb-setup.desktop.in
	data/icons/Makefile
	po/Makefile.in])

AC_OUTPUT

echo "
$PACKAGE_NAME $PACKAGE_VERSION

    Install Prefix:               ${prefix}
    Datadir:                      ${expanded_datadir}
    Libdir:                       ${expanded_libdir}
    D-Bus dir:                    ${DBUS_SERVICES_DIR}
    Python dir:                   ${pythondir}
"
