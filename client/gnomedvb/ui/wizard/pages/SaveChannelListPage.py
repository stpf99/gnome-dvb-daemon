# -*- coding: utf-8 -*-
import gnomedvb
import gtk
import gobject
from gettext import gettext as _
from BasePage import BasePage

class SaveChannelListPage(BasePage):

	__gsignals__ = {
        "finished": (gobject.SIGNAL_RUN_LAST, gobject.TYPE_NONE, [bool]),
    }

	def __init__(self):
		BasePage.__init__(self)
		self.__scanner = None
		
		text = _("Choose a location where you want to save the list of channels.")
		label = gtk.Label(text)
		self.pack_start(label)

		button_box = gtk.HButtonBox()
		self.pack_start(button_box)
	
		save_button = gtk.Button(stock=gtk.STOCK_SAVE)
		save_button.connect("clicked", self.__on_save_button_clicked)
		button_box.pack_start(save_button)
			
	def get_page_title(self):
		return _("Save channels")
	
	def set_scanner(self, scanner):
		self.__scanner = scanner
		
	def __on_save_button_clicked(self, button):
		filechooser = gtk.FileChooserDialog(action=gtk.FILE_CHOOSER_ACTION_SAVE,
			buttons=(gtk.STOCK_CANCEL, gtk.RESPONSE_CANCEL,
			gtk.STOCK_SAVE, gtk.RESPONSE_OK))
		filechooser.set_do_overwrite_confirmation(True)
		if (filechooser.run() == gtk.RESPONSE_OK):
			self.__scanner.write_channels_to_file(filechooser.get_filename())
			self.emit("finished", True)
		filechooser.destroy()

