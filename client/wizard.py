#!/usr/bin/env python
# -*- coding: utf-8 -*-
import gtk
import gobject
import gnomedvb
import dbus
import os
import os.path
import re

SUPPORTED_DVB_TYPES = ("DVB-C", "DVB-S", "DVB-T")

DVB_APPS_DIRS = ("/usr/share/dvb",
				 "/usr/share/dvb-apps",
				 "/usr/share/doc/dvb-utils/examples/scan")

class BasePage(gtk.VBox):

	def __init__(self):
		gtk.VBox.__init__(self, False, 5)
		self.set_border_width(5)

class IntroPage(BasePage):
	
	def __init__(self):
		BasePage.__init__(self)
		self.set_border_width(5)
		
		text = "This wizard will guide you through the process of setting up your DVB cards."
		label = gtk.Label(text)
		label.set_line_wrap(True)
		self.pack_start(label)
		
class AdaptersPage(BasePage):
	
	def __init__(self):
		BasePage.__init__(self)
		
		text = "Select device you want to scan channels."
		label = gtk.Label(text)
		label.set_line_wrap(True)
		self.pack_start(label)
		
		self.deviceslist = gtk.ListStore(str, str, int, int)
		self.get_dvb_devices()
		
		self.devicesview = gtk.TreeView(self.deviceslist)
		
		cell_name = gtk.CellRendererText()
		col_name = gtk.TreeViewColumn("Name")
		col_name.pack_start(cell_name)
		col_name.add_attribute(cell_name, "text", 0)
		self.devicesview.append_column(col_name)
		
		cell_type = gtk.CellRendererText()
		col_type = gtk.TreeViewColumn("Type")
		col_type.pack_start(cell_type)
		col_type.add_attribute(cell_type, "text", 1)
		self.devicesview.append_column(col_type)
		
		scrolledview = gtk.ScrolledWindow()
		scrolledview.set_shadow_type(gtk.SHADOW_ETCHED_IN)
		scrolledview.set_policy(gtk.POLICY_AUTOMATIC, gtk.POLICY_AUTOMATIC)
		scrolledview.add(self.devicesview)
		
		self.pack_start(scrolledview)
		
	def get_selected_device(self):
		model, aiter = self.devicesview.get_selection().get_selected()
		if aiter != None:
			return None
		else:
			return model[aiter]
		
	def get_dvb_devices(self):
		for info in gnomedvb.get_dvb_devices():
			if info["type"] in SUPPORTED_DVB_TYPES:
				self.deviceslist.append([info["name"], info["type"],
					info["adapter"], info["frontend"]])

class InitialTuningDataPage(BasePage):
	
	__gsignals__ = {
		    "finished": (gobject.SIGNAL_RUN_LAST, gobject.TYPE_NONE, []),
	}

	def __init__(self):
		BasePage.__init__(self)
		
		self.__adapter_info = None
		self.__tuning_data = []
		
	def set_adapter_info(self, info):
		self.__adapter_info = info
		
		for widget in self.get_children():
			widget.destroy()
		
		if info["type"] == "DVB-T":
			self.setup_dvb_t()
		elif info["type"] == "DVB-S":
			self.setup_dvb_s()
		elif info["type"] == "DVB-C":
			self.setup_dvb_c()
			
	def get_tuning_data(self):
		return self.__tuning_data
		
	def setup_dvb_t(self):
		countries = { "at": "Austria", "au": "Australia", "be": "Belgium",
 	        "ch": "Switzerland", "cz": "Czech Republic", "de": "Germany",
 	        "dk": "Denmark", "es": "Spain", "fi": "Finland", "fr": "France",
 	        "gr": "Greece", "hr": "Hungary", "is": "Iceland", "it": "Italy",
 	        "lu": "Luxemburg", "nl": "Netherlands", "nz": "New Zealand",
 	        "pl": "Poland", "se": "Sweden", "sk": "Slovakia", "tw": "Taiwan",
 	        "uk": "United Kingdom" }
	
		self.table = gtk.Table(rows=4, columns=2)
		self.table.set_row_spacings(6)
		self.table.set_col_spacings(3)
		self.table.show()
		self.pack_start(self.table)
		
		country = gtk.Label()
		country.set_markup("<b>Country:</b>")
		country.show()
		self.table.attach(country, 0, 1, 0, 1, yoptions=0)
	
		self.countries = gtk.ListStore(str, str)
		self.countries.set_sort_column_id(0, gtk.SORT_ASCENDING)
		
		for code, name in countries.items():
			self.countries.append([name, code])
	
		self.country_combo = gtk.ComboBox(self.countries)
		self.country_combo.connect('changed', self.on_country_changed)
		cell = gtk.CellRendererText()
		self.country_combo.pack_start(cell)
		self.country_combo.add_attribute(cell, "text", 0)
		self.country_combo.show()
		self.table.attach(self.country_combo, 1, 2, 0, 1, yoptions=0)
		
		self.antenna_label = gtk.Label()
		self.antenna_label.set_markup("<b>Antenna:</b>")
		self.antenna_label.hide()
		self.table.attach(self.antenna_label, 0, 1, 1, 2, yoptions=0)
		
		self.antennas = gtk.ListStore(str, str)
		self.antennas.set_sort_column_id(0, gtk.SORT_ASCENDING)
		
		self.antenna_combo = gtk.ComboBox(self.antennas)
		self.antenna_combo.connect('changed', self.on_antenna_changed)
		cell = gtk.CellRendererText()
		self.antenna_combo.pack_start(cell)
		self.antenna_combo.add_attribute(cell, "text", 0)
		self.table.attach(self.antenna_combo, 1, 2, 1, 2, yoptions=0)
		self.antenna_combo.hide()
		
	def setup_dvb_s(self):
		hbox = gtk.HBox(spacing=6)
		hbox.show()
		self.pack_start(hbox, False)
		
		satellite = gtk.Label()
		satellite.set_markup("<b>Satellite:</b>")
		satellite.show()
		hbox.pack_start(satellite, False, False, 0)
		
		self.satellites = gtk.ListStore(str, str)
		self.satellites.set_sort_column_id(0, gtk.SORT_ASCENDING)
		
		self.satellite_combo = gtk.ComboBox(self.satellites)
		self.satellite_combo.connect("changed", self.on_satellite_changed)
		cell = gtk.CellRendererText()
		self.satellite_combo.pack_start(cell)
		self.satellite_combo.add_attribute(cell, "text", 0)
		self.satellite_combo.show()
		hbox.pack_start(self.satellite_combo, False, False, 0)
		
		self.read_satellites()
		
	def setup_dvb_c(self):
		pass
	
	def on_country_changed(self, combo):
		aiter = combo.get_active_iter()
		
		if aiter != None:
			selected_country = self.countries[aiter][1]
	
			self.antennas.clear()
			for d in DVB_APPS_DIRS:
				if os.access(d, os.F_OK | os.R_OK):
					for f in os.listdir(os.path.join(d, 'dvb-t')):
						country, city = f.split('-', 1)
					
						if country == selected_country:
							self.antennas.append([city, os.path.join(d, 'dvb-t', f)])
		
			self.antenna_label.show()
			self.antenna_combo.show()
		
	def on_antenna_changed(self, combo):
		aiter = combo.get_active_iter()
		
		if aiter != None:
			self.__tuning_data = self.antennas[aiter][1]
			self.emit("finished")
	
	def read_satellites(self):
		for d in DVB_APPS_DIRS:
				if os.access(d, os.F_OK | os.R_OK):
					for f in os.listdir(os.path.join(d, 'dvb-s')):
						self.satellites.append([f, os.path.join(d, 'dvb-s', f)])
						
	def on_satellite_changed(self, combo):
		aiter = combo.get_active_iter()
		
		if aiter != None:
			self.__tuning_data = self.satellites[aiter][1]
			self.emit("finished")
		
class ChannelScanPage(BasePage):

	__gsignals__ = {
        "finished": (gobject.SIGNAL_RUN_LAST, gobject.TYPE_NONE, []),
    }

	def __init__(self):
		BasePage.__init__(self)
		
		self.label = gtk.Label()
		self.label.set_line_wrap(True)
		self.pack_start(self.label)
		
		hbox = gtk.HBox(spacing=12)
		hbox.set_border_width(6)
		self.pack_start(hbox)
		
		# TV
		self.tvchannels = gtk.ListStore(str, int)
		self.tvchannelsview = gtk.TreeView(self.tvchannels)
		
		cell_name = gtk.CellRendererText()
		col_name = gtk.TreeViewColumn("Name")
		col_name.pack_start(cell_name)
		col_name.add_attribute(cell_name, "markup", 0)
		self.tvchannelsview.append_column (col_name)
		
		cell_freq = gtk.CellRendererText()
		col_freq = gtk.TreeViewColumn("Frequency")
		col_freq.pack_start(cell_freq, False)
		col_freq.add_attribute(cell_freq, "text", 1)
		self.tvchannelsview.append_column (col_freq)
		
		scrolledtvview = gtk.ScrolledWindow()
		scrolledtvview.set_border_width(6)
		scrolledtvview.add(self.tvchannelsview)
		scrolledtvview.set_shadow_type(gtk.SHADOW_ETCHED_IN)
		scrolledtvview.set_policy(gtk.POLICY_AUTOMATIC, gtk.POLICY_AUTOMATIC)

		tvframe = gtk.Frame("TV channels")
		tvframe.add(scrolledtvview)
		
		hbox.pack_start(tvframe)
		
		# Radio
		self.radiochannels = gtk.ListStore(str, int)
		self.radiochannelsview = gtk.TreeView(self.radiochannels)
		
		cell_name = gtk.CellRendererText()
		col_name = gtk.TreeViewColumn("Name")
		col_name.pack_start(cell_name)
		col_name.add_attribute(cell_name, "markup", 0)
		self.radiochannelsview.append_column (col_name)
		
		cell_freq = gtk.CellRendererText()
		col_freq = gtk.TreeViewColumn("Frequency")
		col_freq.pack_start(cell_freq, False)
		col_freq.add_attribute(cell_freq, "text", 1)
		self.radiochannelsview.append_column (col_freq)
		
		scrolledradioview = gtk.ScrolledWindow()
		scrolledradioview.set_border_width(6)
		scrolledradioview.add(self.radiochannelsview)
		scrolledradioview.set_shadow_type(gtk.SHADOW_ETCHED_IN)
		scrolledradioview.set_policy(gtk.POLICY_AUTOMATIC, gtk.POLICY_AUTOMATIC)
		
		radioframe = gtk.Frame("Radio channels")
		radioframe.add(scrolledradioview)
		
		hbox.pack_start(radioframe)
		
		self.progressbar = gtk.ProgressBar()
		self.pack_start(self.progressbar, False)
		
	def set_name(self, name):
		self.label.set_text("Scanning for channels on device %s" % name)
		
	def start_scanning(self, adapter, frontend, tuning_data):
		manager = gnomedvb.DVBManagerClient()
		
		scanner = manager.get_scanner_for_device(adapter, frontend)
		
		#scanner.connect ("frequency-scanned", self.__on_freq_scanned)
		scanner.connect ("channel-added", self.__on_channel_added)
		scanner.connect ("finished", self.__on_finished)
		scanner.add_scanning_data_from_file (tuning_data)
		
		scanner.run()
		
		return scanner
		
	def __on_channel_added(self, scanner, freq, sid, name, network, channeltype):
		if channeltype == "TV":
			self.tvchannels.append([name, freq])
		elif channeltype == "Radio":
			self.radiochannels.append([name, freq])
		
	def __on_finished(self, scanner):
		self.emit("finished")
		
class SaveChannelListPage(BasePage):

	__gsignals__ = {
        "finished": (gobject.SIGNAL_RUN_LAST, gobject.TYPE_NONE, []),
    }

	def __init__(self):
		BasePage.__init__(self)
		self.__scanner = None
		
		text = "Choose a location where you want to save the list of channels."
		label = gtk.Label(text)
		self.pack_start(label)

		button_box = gtk.HButtonBox()
		self.pack_start(button_box)
	
		save_button = gtk.Button(stock=gtk.STOCK_SAVE)
		save_button.connect("clicked", self.__on_save_button_clicked)
		button_box.pack_start(save_button)
		
	def set_scanner(self, scanner):
		self.__scanner = scanner
		
	def __on_save_button_clicked(self, button):
		filechooser = gtk.FileChooserDialog(action=gtk.FILE_CHOOSER_ACTION_SAVE,
			buttons=(gtk.STOCK_CANCEL, gtk.RESPONSE_CANCEL,
			gtk.STOCK_SAVE, gtk.RESPONSE_OK))
		filechooser.set_do_overwrite_confirmation(True)
		if (filechooser.run() == gtk.RESPONSE_OK):
			self.__scanner.write_channels_to_file(filechooser.get_filename())
			self.emit("finished")
		filechooser.destroy()

class SummaryPage(BasePage):

	def __init__(self):
		BasePage.__init__(self)
		
		text = "Your DVB cards are now setup."
		label = gtk.Label(text)
		label.set_line_wrap(True)
		self.pack_start(label)

class SetupWizard(gtk.Assistant):

	def __init__(self):
		gtk.Assistant.__init__(self)
		self.__ask_on_exit = True
		self.__adapter_info = None
		self.__scanner = None
		
		self.connect ('delete-event', self.confirm_quit)
		self.connect ('cancel', self.confirm_quit)
		self.connect ('close', self.confirm_quit)
		self.connect ('prepare', self.on_prepare)
		self.set_default_size(500, 400)
		
		intro_page = IntroPage()
		self.append_page(intro_page)
		self.set_page_title(intro_page, "Welcome")
		self.set_page_type(intro_page, gtk.ASSISTANT_PAGE_INTRO)
		self.set_page_complete(intro_page, True)
		
		self.adapters_page = AdaptersPage()
		self.append_page(self.adapters_page)
		self.set_page_title(self.adapters_page, "Setup adapter")
		self.set_page_type(self.adapters_page, gtk.ASSISTANT_PAGE_CONTENT)
		
		self.adapters_page.devicesview.get_selection().connect('changed',
			self.on_device_selection_changed)
		
		self.tuning_data_page = InitialTuningDataPage()
		self.tuning_data_page.connect("finished", self.on_scan_finished)
		self.append_page(self.tuning_data_page)
		self.set_page_title(self.tuning_data_page, "Select tuning data")
		self.set_page_type(self.tuning_data_page, gtk.ASSISTANT_PAGE_CONTENT)
		
		scan_page = ChannelScanPage()
		scan_page.connect("finished", self.on_scan_finished)
		self.append_page(scan_page)
		self.set_page_title(scan_page, "Scanning for channels")
		self.set_page_type(scan_page, gtk.ASSISTANT_PAGE_PROGRESS)
		
		save_channels_page = SaveChannelListPage()
		save_channels_page.connect("finished", self.on_scan_finished)
		self.append_page(save_channels_page)
		self.set_page_title(save_channels_page, "Save channels")
		self.set_page_type(save_channels_page, gtk.ASSISTANT_PAGE_CONTENT)
		
		summary_page = SummaryPage()
		self.append_page(summary_page)
		self.set_page_title(summary_page, "Setup finished")
		self.set_page_type(summary_page, gtk.ASSISTANT_PAGE_SUMMARY)
		
	def on_prepare(self, assistant, page):
		if isinstance(page, InitialTuningDataPage):
			page.set_adapter_info(self.__adapter_info)
		elif isinstance(page, ChannelScanPage):
			if self.__adapter_info["name"] != None:
				page.set_name(self.__adapter_info["name"])
				self.__scanner = page.start_scanning(self.__adapter_info["adapter"],
					self.__adapter_info["frontend"], self.tuning_data_page.get_tuning_data ())
		elif isinstance(page, SaveChannelListPage):
			page.set_scanner(self.__scanner)
		elif isinstance(page, SummaryPage):
			self.__ask_on_exit = False
		
	def on_device_selection_changed(self, treeselection):
		model, aiter = treeselection.get_selected()
		if aiter != None:
			self.__adapter_info = {"name": model[aiter][0],
								   "type": model[aiter][1],
								   "adapter": model[aiter][2],
								   "frontend": model[aiter][3]}
			self.set_page_complete(self.adapters_page, True)
		else:
			self.set_page_complete(self.adapters_page, False)
			
	def on_scan_finished(self, page):
		self.set_page_complete(page, True)
			
	def confirm_quit(self, *args):
		if self.__ask_on_exit:
			dialog = gtk.MessageDialog(parent=self,
				flags=gtk.DIALOG_MODAL | gtk.DIALOG_DESTROY_WITH_PARENT,
				type=gtk.MESSAGE_QUESTION,
				buttons=gtk.BUTTONS_YES_NO,
				message_format="Are you sure you want to abort?\nAll process will be lost.")
			
			response = dialog.run()
			if response == gtk.RESPONSE_YES:
				if self.__scanner != None:
					self.__scanner.destroy()
				gtk.main_quit()
			elif response == gtk.RESPONSE_NO:
				dialog.destroy()
		
			return True
		else:
			if self.__scanner != None:
				self.__scanner.destroy()
			gtk.main_quit()
		
if __name__ == '__main__':
	w = SetupWizard()
	w.show_all()
	gtk.main ()
	
