dnl Checks for gstreamer modules (code from Totem)
dnl AG_GST_CHECK_GST_INSPECT
dnl   check for gst-inspect-0.10
dnl
dnl AG_GST_CHECK_MODULE_BAD([MODULE])
dnl   check for module from gst-plugins-bad

AC_DEFUN([AG_GST_CHECK_GST_INSPECT],
[
	gst010_toolsdir=`$PKG_CONFIG --variable=toolsdir gstreamer-0.10`
	GST_INSPECT="$gst010_toolsdir/gst-inspect-0.10"

	dnl Give error and exit if we don't have the gst_inspect tool
	AC_MSG_CHECKING([GStreamer 0.10 inspection tool])
	if test -r "$GST_INSPECT"; then
		AC_MSG_RESULT([yes])
		AC_SUBST(GST_INSPECT)
	else
		AC_MSG_RESULT([no])
		AC_MSG_ERROR([
Cannot find required GStreamer-0.10 tool 'gst-inspect-0.10'.
It should be part of gstreamer-0_10-utils. Please install it.
		])
	fi
])

AC_DEFUN([AG_GST_CHECK_MODULE_BAD],
[
	base_element="[$1]"
	
    AC_MSG_CHECKING([GStreamer 0.10 $base_element plugin])
	if $GST_INSPECT $base_element >/dev/null 2>/dev/null; then
		AC_MSG_RESULT([yes])
	else
		AC_MSG_RESULT([no])
		AC_MSG_ERROR([
Cannot find required GStreamer-0.10 plugin '$base_element'.
It should be part of gst-plugins-bad. Please install it.
		])
	fi
])
