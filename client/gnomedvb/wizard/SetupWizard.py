# -*- coding: utf-8 -*-
import gnomedvb
import gtk
import gobject
from gettext import gettext as _
from pages.IntroPage import IntroPage
from pages.AdaptersPage import AdaptersPage
from pages.InitialTuningDataPage import InitialTuningDataPage
from pages.ChannelScanPage import ChannelScanPage
from pages.SaveChannelListPage import SaveChannelListPage
from pages.SummaryPage import SummaryPage

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
		self.set_page_title(intro_page, _("Welcome"))
		self.set_page_type(intro_page, gtk.ASSISTANT_PAGE_INTRO)
		self.set_page_complete(intro_page, True)
		
		self.adapters_page = AdaptersPage()
		self.append_page(self.adapters_page)
		self.set_page_title(self.adapters_page, _("Setup adapter"))
		self.set_page_type(self.adapters_page, gtk.ASSISTANT_PAGE_CONTENT)
		
		self.adapters_page.devicesview.get_selection().connect('changed',
			self.on_device_selection_changed)
		
		self.tuning_data_page = InitialTuningDataPage()
		self.tuning_data_page.connect("finished", self.on_scan_finished)
		self.append_page(self.tuning_data_page)
		self.set_page_title(self.tuning_data_page, _("Select tuning data"))
		self.set_page_type(self.tuning_data_page, gtk.ASSISTANT_PAGE_CONTENT)
		
		scan_page = ChannelScanPage()
		scan_page.connect("finished", self.on_scan_finished)
		self.append_page(scan_page)
		self.set_page_title(scan_page, _("Scanning for channels"))
		self.set_page_type(scan_page, gtk.ASSISTANT_PAGE_PROGRESS)
		
		save_channels_page = SaveChannelListPage()
		save_channels_page.connect("finished", self.on_scan_finished)
		self.append_page(save_channels_page)
		self.set_page_title(save_channels_page, _("Save channels"))
		self.set_page_type(save_channels_page, gtk.ASSISTANT_PAGE_CONTENT)
		
		summary_page = SummaryPage()
		self.append_page(summary_page)
		self.set_page_title(summary_page, _("Setup finished"))
		self.set_page_type(summary_page, gtk.ASSISTANT_PAGE_SUMMARY)
		
	def on_prepare(self, assistant, page):
		if isinstance(page, InitialTuningDataPage):
			page.set_adapter_info(self.__adapter_info)
		elif isinstance(page, ChannelScanPage):
			if self.__adapter_info["name"] != None:
				page.set_name(self.__adapter_info["name"])
				self.__scanner = page.start_scanning(self.__adapter_info["adapter"],
					self.__adapter_info["frontend"], self.tuning_data_page.get_tuning_data ())
				if self.__scanner == None:
					print "Invalid scanning data"
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
			
	def on_scan_finished(self, page, state):
		self.set_page_complete(page, state)
			
	def confirm_quit(self, *args):
		if self.__ask_on_exit:
			dialog = gtk.MessageDialog(parent=self,
				flags=gtk.DIALOG_MODAL | gtk.DIALOG_DESTROY_WITH_PARENT,
				type=gtk.MESSAGE_QUESTION,
				buttons=gtk.BUTTONS_YES_NO,
				message_format=_("Are you sure you want to abort?\nAll process will be lost."))
			
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

