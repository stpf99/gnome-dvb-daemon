# -*- coding: utf-8 -*-
# Copyright (C) 2009 Sebastian Pölsterl
#
# This file is part of GNOME DVB Daemon.
#
# GNOME DVB Daemon is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# GNOME DVB Daemon is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with GNOME DVB Daemon.  If not, see <http://www.gnu.org/licenses/>.

import datetime
import gtk
import gnomedvb
from gettext import gettext as _

class PairBox(gtk.HBox):
    def __init__(self, name, text=None):
        gtk.HBox.__init__(self, spacing=3)
        
        name_label = gtk.Label()
        name_label.set_markup(name)
        name_label.show()
        self.pack_start(name_label, False)
        
        text_ali = gtk.Alignment()
        text_ali.show()
        self.pack_start(text_ali)
        
        self.text_label = gtk.Label(text)
        self.text_label.show()
        text_ali.add(self.text_label)
        
    def get_text_label(self):
        return self.text_label

class DetailsDialog(gtk.Dialog):

    def __init__(self, rec_id, parent=None):
        gtk.Dialog.__init__(self, title=_("Details"),
            parent=parent,
            flags=gtk.DIALOG_DESTROY_WITH_PARENT,
            buttons=(gtk.STOCK_CLOSE, gtk.RESPONSE_CLOSE))
        
        self.set_default_size(440, 350)
        self.vbox.set_spacing(6)
        
        title_hbox = PairBox(_("<b>Title:</b>"))
        self.title_label = title_hbox.get_text_label()
        title_hbox.show_all()
        self.vbox.pack_start(title_hbox, False)
        
        channel_hbox = PairBox(_("<b>Channel:</b>"))
        self.channel = channel_hbox.get_text_label()
        channel_hbox.show_all()
        self.vbox.pack_start(channel_hbox, False)
        
        date_hbox = PairBox(_("<b>Date:</b>"))
        self.date = date_hbox.get_text_label()
        date_hbox.show_all()
        self.vbox.pack_start(date_hbox, False)
        
        duration_hbox = PairBox(_("<b>Duration:</b>"))
        self.duration = duration_hbox.get_text_label()
        duration_hbox.show_all()
        self.vbox.pack_start(duration_hbox, False)
        
        label_description = gtk.Label()
        label_description.set_markup(_("<b>Description:</b>"))
        label_description.show()
        
        ali_desc = gtk.Alignment()
        ali_desc.show()
        ali_desc.add(label_description)
        self.vbox.pack_start(ali_desc, False)
            
        self.textview = gtk.TextView()
        self.textview.set_editable(False)
        self.textview.set_wrap_mode(gtk.WRAP_WORD)
        self.textview.show()
        
        desc_text_ali = gtk.Alignment(xscale=1.0, yscale=1.0)
        desc_text_ali.set_padding(0, 0, 12, 0)
        desc_text_ali.show()
        self.vbox.pack_start(desc_text_ali)
        
        scrolledwin = gtk.ScrolledWindow()
        scrolledwin.set_policy(gtk.POLICY_NEVER, gtk.POLICY_AUTOMATIC)
        scrolledwin.set_shadow_type(gtk.SHADOW_IN)
        scrolledwin.add(self.textview)
        scrolledwin.show()
        desc_text_ali.add(scrolledwin)
        
        self._fill(rec_id)
        
    def _fill(self, rec_id):
        recstore = gnomedvb.DVBRecordingsStoreClient()
        infos = recstore.get_all_informations(rec_id)
        self.set_title(infos[1])
        self.set_description(infos[2])
        self.set_duration(infos[3])
        self.set_date(infos[4])
        self.set_channel(infos[5])
        
    def set_description(self, text):
        self.textview.get_buffer().set_text(text)
        
    def set_title(self, title):
        gtk.Dialog.set_title(self, title)
        self.title_label.set_text(title)

    def set_channel(self, channel):
        self.channel.set_text(channel)
        
    def set_duration(self, duration):
        self.duration.set_text(_("%d min") % duration)
        
    def set_date(self, timestamp):
        date = datetime.datetime.fromtimestamp(timestamp)
        self.date.set_text(date.strftime("%c"))

