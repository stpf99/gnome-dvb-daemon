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
		self.__ask_on_exit = False
		self.__adapter_info = None
		self.__scanner = None
		
		self.connect ('delete-event', self.confirm_quit)
		self.connect ('cancel', self.confirm_quit)
		self.connect ('close', self.confirm_quit)
		self.connect ('prepare', self.on_prepare)
		self.set_default_size(500, 400)
		self.set_title(_("Setup DVB"))
		
		intro_page = IntroPage()
		self.append_page(intro_page)
		self.set_page_complete(intro_page, True)
		
		self.adapters_page = AdaptersPage()
		self.adapters_page.connect("finished", self.on_adapter_page_finished)
		self.append_page(self.adapters_page)
		
		self.tuning_data_page = InitialTuningDataPage()
		self.tuning_data_page.connect("finished", self.on_scan_finished)
		self.append_page(self.tuning_data_page)
		
		scan_page = ChannelScanPage()
		scan_page.connect("finished", self.on_scan_finished)
		self.append_page(scan_page)
		
		save_channels_page = SaveChannelListPage()
		save_channels_page.connect("finished", self.on_scan_finished)
		self.append_page(save_channels_page)
		
		summary_page = SummaryPage()
		self.append_page(summary_page)
		
	def append_page(self, page):
		gtk.Assistant.append_page(self, page)
		self.set_page_title(page, page.get_page_title())
		self.set_page_type(page, page.get_page_type())
		
	def on_prepare(self, assistant, page):
		if isinstance(page, InitialTuningDataPage):
			page.set_adapter_info(self.__adapter_info)
		elif isinstance(page, ChannelScanPage):
			self.__ask_on_exit = True
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
		
	def on_scan_finished(self, page, state):
		self.set_page_complete(page, state)
			
	def on_adapter_page_finished(self, page, state):
		if state:
			self.__adapter_info = page.get_adapter_info()
		self.on_scan_finished(page, state)
			
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

