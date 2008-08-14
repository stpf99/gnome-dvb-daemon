# -*- coding: utf-8 -*-
import gobject
import gnomedvb
import gtk
from gettext import gettext as _
from BasePage import BasePage
		
SUPPORTED_DVB_TYPES = ("DVB-C", "DVB-S", "DVB-T")

class AdaptersPage(BasePage):
	
	__gsignals__ = {
        "finished": (gobject.SIGNAL_RUN_LAST, gobject.TYPE_NONE, [bool]),
    }

	def __init__(self):
		BasePage.__init__(self)
		
		self.__adapter_info = {}
		
		label = gtk.Label()
		label.set_line_wrap(True)
		self.pack_start(label)
		
		self.deviceslist = gtk.ListStore(str, str, int, int)
		self.get_dvb_devices()
		
		if len(self.deviceslist) == 0:
			text = _('<big><span weight="bold">No devices have been found.</span></big>')
			text += "\n\n"
			text += _('Either no DVB cards are installed or all cards are busy. In the latter case make sure you close all programs such as video players that access your DVB card.')
			label.set_markup (text)
			
			self.emit("finished", False)
		else:
			text = _("Select device you want to scan channels.")
			label.set_markup (text)
		
			self.devicesview = gtk.TreeView(self.deviceslist)
			self.devicesview.get_selection().connect("changed",
				self.on_device_selection_changed)
		
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
			
			self.emit("finished", True)
		
	def get_page_title(self):
		return _("Setup adapter")
	
	def get_selected_device(self):
		model, aiter = self.devicesview.get_selection().get_selected()
		if aiter != None:
			return None
		else:
			return model[aiter]
		
	def get_adapter_info(self):
		return self.__adapter_info
		
	def get_dvb_devices(self):
		for info in gnomedvb.get_dvb_devices():
			# TODO: Retrieve name and type
			#if info["type"] in SUPPORTED_DVB_TYPES:
			self.deviceslist.append(["name", "DVB-T",
				info["adapter"], info["frontend"]])
	
	def on_device_selection_changed(self, treeselection):
		model, aiter = treeselection.get_selected()
		if aiter != None:
			self.__adapter_info = {"name": model[aiter][0],
								   "type": model[aiter][1],
								   "adapter": model[aiter][2],
								   "frontend": model[aiter][3]}
			self.emit("finished", True)
		else:
			self.emit("finished", False)
		
