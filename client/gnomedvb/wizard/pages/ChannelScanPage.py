# -*- coding: utf-8 -*-
import gnomedvb
import gtk
import gobject
from gettext import gettext as _
from BasePage import BasePage

class ChannelScanPage(BasePage):

	__gsignals__ = {
        "finished": (gobject.SIGNAL_RUN_LAST, gobject.TYPE_NONE, [bool]),
    }

	def __init__(self):
		BasePage.__init__(self)
		
		self._max_freqs = 0
		self._scanned_freqs = 0
		self._last_qsize = 0
		
		self._theme = gtk.icon_theme_get_default()
		
		self.label = gtk.Label()
		self.label.set_line_wrap(True)
		self.pack_start(self.label, False)
		
		hbox = gtk.HBox(spacing=12)
		hbox.set_border_width(6)
		self.pack_start(hbox)
		
		# TV
		self.tvchannels = gtk.ListStore(gtk.gdk.Pixbuf, str, int)
		self.tvchannelsview = gtk.TreeView(self.tvchannels)
		
		#self.tvchannelsview.append_column (col_icon)
		
		col_name = gtk.TreeViewColumn(_("Name"))
		
		cell_icon = gtk.CellRendererPixbuf()
		col_name.pack_start(cell_icon, False)
		col_name.add_attribute(cell_icon, "pixbuf", 0)
		
		cell_name = gtk.CellRendererText()
		col_name.pack_start(cell_name)
		col_name.add_attribute(cell_name, "markup", 1)
		self.tvchannelsview.append_column (col_name)
		
		col_freq = gtk.TreeViewColumn(_("Frequency"))
		cell_freq = gtk.CellRendererText()
		col_freq.pack_start(cell_freq, False)
		col_freq.add_attribute(cell_freq, "text", 2)
		self.tvchannelsview.append_column (col_freq)
		
		scrolledtvview = gtk.ScrolledWindow()
		scrolledtvview.set_border_width(6)
		scrolledtvview.add(self.tvchannelsview)
		scrolledtvview.set_shadow_type(gtk.SHADOW_ETCHED_IN)
		scrolledtvview.set_policy(gtk.POLICY_AUTOMATIC, gtk.POLICY_AUTOMATIC)

		hbox.pack_start(scrolledtvview)
		
		self.progressbar = gtk.ProgressBar()
		self.pack_start(self.progressbar, False)
		
	def get_page_title(self):
		return _("Scanning for channels")
		
	def get_page_type(self):
		return gtk.ASSISTANT_PAGE_PROGRESS
		
	def set_name(self, name):
		self.label.set_text(_("Scanning for channels on device %s") % name)
		
	def start_scanning(self, adapter, frontend, tuning_data):
		manager = gnomedvb.DVBManagerClient()
		
		scanner = manager.get_scanner_for_device(adapter, frontend)
		
		scanner.connect ("frequency-scanned", self.__on_freq_scanned)
		scanner.connect ("channel-added", self.__on_channel_added)
		scanner.connect ("finished", self.__on_finished)
		
		if isinstance(tuning_data, str):
			scanner.add_scanning_data_from_file (tuning_data)
		elif isinstance(tuning_data, list):
			for data in tuning_data:
				scanner.add_scanning_data(data)
		else:
			scanner.destroy()
			return None
		
		scanner.run()
		
		return scanner
		
	def __on_channel_added(self, scanner, freq, sid, name, network, channeltype, scrambled):
		try:
			if scrambled:
				icon = self._theme.load_icon("emblem-readonly", 16,
					gtk.ICON_LOOKUP_USE_BUILTIN)
			else:
				if channeltype == "TV":
					icon = self._theme.load_icon("video-x-generic", 16,
						gtk.ICON_LOOKUP_USE_BUILTIN)
				elif channeltype == "Radio":
					icon = self._theme.load_icon("audio-x-generic", 16,
						gtk.ICON_LOOKUP_USE_BUILTIN)
		except gobject.GError:
			icon = None
		
		name = name.replace("&", "&amp;")
		self.tvchannels.append([icon, name, freq])
		
	def __on_finished(self, scanner):
		self.emit("finished", True)
		
	def __on_freq_scanned(self, scanner, freq, qsize):
		if qsize >= self._last_qsize:
			self._max_freqs += qsize - self._last_qsize + 1
		self._scanned_freqs += 1
		fraction = float(self._scanned_freqs) / self._max_freqs
		self.progressbar.set_fraction(fraction)
		self._last_qsize = qsize

