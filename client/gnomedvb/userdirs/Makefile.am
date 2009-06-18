INCLUDES = $(PYTHON_INCLUDES) $(GLIB_CFLAGS)

__userdirsdir = $(pyexecdir)/gnomedvb/userdirs
__userdirs_LTLIBRARIES = __userdirs.la
__userdirs_la_LDFLAGS = -module -avoid-version -export-symbols-regex init__userdirs
__userdirs_la_LIBADD = $(GLIB_LIBS)
__userdirs_la_SOURCES = \
	__userdirsmodule.c 

__userdirs_PYTHON = \
	__init__.py
