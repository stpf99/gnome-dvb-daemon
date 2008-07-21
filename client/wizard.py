#!/usr/bin/env python
# -*- coding: utf-8 -*-
import gtk
import gnomedvb
import dbus
import re

HAL_MANAGER_IFACE = "org.freedesktop.Hal.Manager"
HAL_DEVICE_IFACE = "org.freedesktop.Hal.Device"
HAL_MANAGER_PATH = "/org/freedesktop/Hal/Manager"
HAL_SERVICE = "org.freedesktop.Hal"

SUPPORTED_DVB_TYPES = ("DVB-C", "DVB-S", "DVB-T")

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
		
		self.adapter_pattern = re.compile("adapter(\d+?)/frontend(\d+?)")
		
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
		bus = dbus.SystemBus()
		# Get proxy object
		proxy = bus.get_object(HAL_SERVICE, HAL_MANAGER_PATH)
		# Apply the correct interace to the proxy object
		halmanager = dbus.Interface(proxy, HAL_MANAGER_IFACE)
		objects = halmanager.FindDeviceByCapability("dvb")

		for o in objects:
			proxy = bus.get_object(HAL_SERVICE, o)
			dev = dbus.Interface(proxy, HAL_DEVICE_IFACE)
			#for key, val in dev.GetAllProperties().items():
			#	print key, " - ", val
			dev_file = dev.GetProperty("linux.device_file")
			
			match = self.adapter_pattern.search(dev_file)
			if match != None:
				adapter = int(match.group(1))
				frontend = int(match.group(2))
				adapter_type = gnomedvb.get_adapter_type(adapter)
				if adapter_type in SUPPORTED_DVB_TYPES:
					self.deviceslist.append([dev_file, adapter_type, adapter, frontend])

class ChannelScanPage(BasePage):

	def __init__(self):
		BasePage.__init__(self)
		
		self.label = gtk.Label()
		self.label.set_line_wrap(True)
		self.pack_start(self.label)
		
	def set_name(self, name):
		self.label.set_text("Scanning for channels on device %s" % name)
		
	def start_scanning(self):
		pass

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
		
		# FIXME
		scan_page = ChannelScanPage()
		self.append_page(scan_page)
		self.set_page_title(scan_page, "Scanning for channels")
		self.set_page_type(scan_page, gtk.ASSISTANT_PAGE_PROGRESS)
		
		summary_page = SummaryPage()
		self.append_page(summary_page)
		self.set_page_title(summary_page, "Setup finished")
		self.set_page_type(summary_page, gtk.ASSISTANT_PAGE_SUMMARY)
		
	def on_prepare(self, assistant, page):
		if isinstance(page, ChannelScanPage):
			dev_data = self.adapters_page.get_selected_device()
			if dev_data != None:
				page.set_name(dev_data[0])
		
	def on_device_selection_changed(self, treeselection):
		model, aiter = treeselection.get_selected()
		if aiter != None:
			print model[aiter][0]
			self.set_page_complete(self.adapters_page, True)
		else:
			self.set_page_complete(self.adapters_page, False)
			
	def confirm_quit(self, *args):
		dialog = gtk.MessageDialog(parent=self,
			flags=gtk.DIALOG_MODAL | gtk.DIALOG_DESTROY_WITH_PARENT,
			type=gtk.MESSAGE_QUESTION,
			buttons=gtk.BUTTONS_YES_NO,
			message_format="Are you sure you want to abort?\nAll process will be lost.")
			
		response = dialog.run()
		if response == gtk.RESPONSE_YES:
			gtk.main_quit()
		elif response == gtk.RESPONSE_NO:
			dialog.destroy()
		
		return True
		
if __name__ == '__main__':
	w = SetupWizard()
	w.show_all()
	gtk.main ()
	
