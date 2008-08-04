# -*- coding: utf-8 -*-
import gnomedvb
import gtk
from gettext import gettext as _
from BasePage import BasePage

SUPPORTED_DVB_TYPES = ("DVB-C", "DVB-S", "DVB-T")
		
class AdaptersPage(BasePage):
	
	def __init__(self):
		BasePage.__init__(self)
		
		text = _("Select device you want to scan channels.")
		label = gtk.Label(text)
		label.set_line_wrap(True)
		self.pack_start(label)
		
		self.deviceslist = gtk.ListStore(str, str, int, int)
		self.get_dvb_devices()
		
		self.devicesview = gtk.TreeView(self.deviceslist)
		
		cell_name = gtk.CellRendererText()
		col_name = gtk.TreeViewColumn(_("Name"))
		col_name.pack_start(cell_name)
		col_name.add_attribute(cell_name, "text", 0)
		self.devicesview.append_column(col_name)
		
		cell_type = gtk.CellRendererText()
		col_type = gtk.TreeViewColumn(_("Type"))
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

