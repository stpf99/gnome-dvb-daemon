    
gnomedvbdir = $(pythondir)/gnomedvb
gnomedvb_PYTHON = \
    __init__.py \
    DBusWrapper.py \
    Device.py \
    DVBModel.py \
    defs.py

## user dirs ##
__userdirsdir = $(pythondir)/gnomedvb/userdirs
__userdirs_LTLIBRARIES = __userdirs.la
__userdirs_la_LDFLAGS = -module -avoid-version -export-symbols-regex init__userdirs
__userdirs_la_LIBADD = $(GLIB_LIBS)
__userdirs_la_CPPFLAGS = $(PYTHON_INCLUDES) $(GLIB_CFLAGS)
__userdirs_la_SOURCES = \
	userdirs/__userdirsmodule.c 

__userdirs_PYTHON = \
	userdirs/__init__.py

## ui ##
gnomedvbuidir = $(pythondir)/gnomedvb/ui
gnomedvbui_PYTHON = \
    ui/__init__.py

## ui/controlcenter ##
gnomedvbcontrolcenterdir = $(pythondir)/gnomedvb/ui/controlcenter
gnomedvbcontrolcenter_PYTHON = \
    ui/controlcenter/__init__.py \
    ui/controlcenter/ControlCenterWindow.py

### ui/preferences ###
gnomedvbprefsuidir = $(pythondir)/gnomedvb/ui/preferences
gnomedvbprefsui_PYTHON = \
    ui/preferences/__init__.py \
    ui/preferences/DeviceGroupsView.py \
    ui/preferences/Dialogs.py \
    ui/preferences/Frame.py \
    ui/preferences/Preferences.py

### ui/recordings ###
gnomedvbrecordingsuidir = $(pythondir)/gnomedvb/ui/recordings
gnomedvbrecordingsui_PYTHON = \
    ui/recordings/__init__.py \
    ui/recordings/DetailsDialog.py \
    ui/recordings/RecordingsDialog.py

### ui/timers ###
gnomedvbtimersuidir = $(pythondir)/gnomedvb/ui/timers
gnomedvbtimersui_PYTHON = \
    ui/timers/__init__.py \
    ui/timers/CalendarDialog.py \
    ui/timers/EditTimersDialog.py \
    ui/timers/TimerDialog.py

### ui/widgets ###
gnomedvbprefsmodeldir = $(pythondir)/gnomedvb/ui/widgets
gnomedvbprefsmodel_PYTHON = \
    ui/widgets/__init__.py \
    ui/widgets/ChannelsStore.py \
    ui/widgets/ChannelsView.py \
    ui/widgets/RecordingsStore.py \
    ui/widgets/RecordingsView.py \
    ui/widgets/RunningNextStore.py \
    ui/widgets/RunningNextView.py \
    ui/widgets/ScheduleStore.py \
    ui/widgets/ScheduleView.py

### ui/wizard ###
gnomedvbwizarddir = $(pythondir)/gnomedvb/ui/wizard
gnomedvbwizard_PYTHON = \
    ui/wizard/__init__.py \
    ui/wizard/SetupWizard.py

### ui/wizard/pages ###
gnomedvbwizardpagesdir = $(pythondir)/gnomedvb/ui/wizard/pages
gnomedvbwizardpages_PYTHON = \
    ui/wizard/pages/__init__.py \
    ui/wizard/pages/AdaptersPage.py \
    ui/wizard/pages/BasePage.py \
    ui/wizard/pages/ChannelScanPage.py \
    ui/wizard/pages/InitialTuningDataPage.py \
    ui/wizard/pages/IntroPage.py \
    ui/wizard/pages/SaveChannelListPage.py \
    ui/wizard/pages/SetupDevicePage.py \
    ui/wizard/pages/SummaryPage.py
    
DISTCLEANFILES = \
	defs.py
	
EXTRA_DIST = \
	defs.py.in
