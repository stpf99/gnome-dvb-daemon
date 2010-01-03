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

import gtk
import gnomedvb
import gnomedvb.ui.widgets.DetailsDialog

class DetailsDialog(gnomedvb.ui.widgets.DetailsDialog.DetailsDialog):

    def __init__(self, rec_id, parent=None):
        gnomedvb.ui.widgets.DetailsDialog.DetailsDialog.__init__(self, parent=parent)
        
        self.rec_button.hide()
        self.action_area.set_layout(gtk.BUTTONBOX_END)

        self._fill(rec_id)
        
    def _fill(self, rec_id):
        def get_all_informations_callback(infos, success):
            if success:
                self.set_title(infos[1])
                self.set_description(infos[2])
                self.set_duration(infos[3])
                self.set_date(infos[4])
                self.set_channel(infos[5])
    
        recstore = gnomedvb.DVBRecordingsStoreClient()
        recstore.get_all_informations(rec_id,
            reply_handler=get_all_informations_callback,
            error_handler=gnomedvb.global_error_handler)

