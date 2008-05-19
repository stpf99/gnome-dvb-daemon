AC_INIT([dvb-daemon], [0.1.0], [marduk@k-d-w.org], [dvb-daemon])
AC_CONFIG_SRCDIR([Makefile.am])
AC_CONFIG_HEADERS(config.h)
AM_INIT_AUTOMAKE([dist-bzip2])
AM_MAINTAINER_MODE

AC_PROG_CC
AM_PROG_CC_C_O
AC_DISABLE_STATIC
AC_PROG_LIBTOOL

AC_PATH_PROG(VALAC, valac, valac)
AC_SUBST(VALAC)

AH_TEMPLATE([GETTEXT_PACKAGE], [dvb-daemon])
GETTEXT_PACKAGE=dvb-daemon
AC_DEFINE_UNQUOTED(GETTEXT_PACKAGE, "$GETTEXT_PACKAGE")
AC_SUBST(GETTEXT_PACKAGE)
AM_GLIB_GNU_GETTEXT
IT_PROG_INTLTOOL([0.35.0])

AC_SUBST(CFLAGS)
AC_SUBST(CPPFLAGS)
AC_SUBST(LDFLAGS)

GLIB_REQUIRED=2.16.0
GIO_REQUIRED=2.16.0
GST_REQUIRED=0.10.19
DBUS_REQUIRED=0.74
GEE_REQUIRED=0.1.4

PKG_CHECK_MODULES(DVB_DAEMON, glib-2.0 >= $GLIB_REQUIRED
							gio-2.0 >= $GIO_REQUIRED
                            gobject-2.0 >= $GLIB_REQUIRED
                            gstreamer-0.10 >= $GST_REQUIRED
                            dbus-glib-1 >= $DBUS_REQUIRED
                            gee-1.0 >= $GEE_REQUIRED)
AC_SUBST(DVB_DAEMON_CFLAGS)
AC_SUBST(DVB_DAEMON_LIBS)

dnl Expansions
SHAMROCK_EXPAND_DATADIR
SHAMROCK_EXPAND_LIBDIR

dnl ****************************************************************************
dnl * Check for DBUS Services directory
dnl ****************************************************************************
DBUS_REQUIRED_VERSION=1.1
PKG_CHECK_MODULES(DBUS, dbus-1 >= $DBUS_REQUIRED_VERSION)
DBUS_SERVICES_DIR="$expanded_datadir/dbus-1/services"
AC_SUBST(DBUS_SERVICES_DIR)
AC_DEFINE_UNQUOTED(DBUS_SERVICES_DIR, "$DBUS_SERVICES_DIR", [DBus services directory])

AC_CONFIG_FILES([
    Makefile
    data/Makefile
	po/Makefile.in])

AC_OUTPUT

echo "
$PACKAGE_NAME $PACKAGE_VERSION

    Install Prefix:               ${prefix}
    Datadir:                      ${expanded_datadir}
    Libdir:                       ${expanded_libdir}
    D-Bus dir:                    ${DBUS_SERVICES_DIR}
"
