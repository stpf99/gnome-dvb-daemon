# -*- coding: utf-8 -*-
# Copyright (C) 2008,2009 Sebastian Pölsterl
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
from gettext import gettext as _
import gnomedvb
from gnomedvb import global_error_handler
from gnomedvb.ui.timers.TimerDialog import TimerDialog, NoTimerCreatedDialog

class EditTimersDialog(gtk.Dialog):

    (COL_ID,
    COL_CHANNEL,
    COL_TITLE,
    COL_START,
    COL_DURATION,
    COL_ACTIVE,) = range(6)
    
    def __init__(self, device_group, parent=None):
        """
        @param device_group: ID of device group
        @type device_group: int
        @param parent: Parent window
        @type parent: gtk.Window
        """
        gtk.Dialog.__init__(self, title=_("Recording schedule"),
            parent=parent,
            flags=gtk.DIALOG_MODAL | gtk.DIALOG_DESTROY_WITH_PARENT)
        
        self.device_group = device_group
        self.set_recorder(device_group)
        
        close_button = self.add_button(gtk.STOCK_CLOSE, gtk.RESPONSE_CLOSE)
        close_button.grab_default()
        
        self.set_size_request(550, 400)
        self.set_has_separator(False)
        self.set_border_width(5)
        
        self.vbox_main = gtk.VBox(spacing=12)
        self.vbox_main.set_border_width(5)
        self.vbox_main.show()
        self.vbox.pack_start(self.vbox_main)
        
        self.timerslist = gtk.ListStore(int, str, str, str, int, bool)
        self.timerslist.set_sort_column_id(self.COL_START, gtk.SORT_ASCENDING)
        
        self.timersview = gtk.TreeView(self.timerslist)
        self.timersview.get_selection().connect("changed",
            self._on_timers_selection_changed)

        col_channel = gtk.TreeViewColumn(_("Channel"))
        cell_rec = gtk.CellRendererPixbuf()
        col_channel.pack_start(cell_rec)
        col_channel.set_cell_data_func(cell_rec, self._get_recording_icon_for_cell)
        col_channel.add_attribute(cell_rec, "stock-id", self.COL_ACTIVE)
        cell_channel = gtk.CellRendererText()
        col_channel.pack_start(cell_channel)
        col_channel.add_attribute(cell_channel, "text", self.COL_CHANNEL)

        self.timersview.append_column(col_channel)

        col_title = gtk.TreeViewColumn(_("Title"))
        cell_title = gtk.CellRendererText()
        col_title.pack_start(cell_title)
        col_title.add_attribute(cell_title, "text", self.COL_TITLE)
        
        self.timersview.append_column(col_title)
        
        cell_starttime = gtk.CellRendererText()
        col_starttime = gtk.TreeViewColumn(_("Start time"))
        col_starttime.pack_start(cell_starttime)
        col_starttime.add_attribute(cell_starttime, "text", self.COL_START)
        
        self.timersview.append_column(col_starttime)
        
        cell_duration = gtk.CellRendererText()
        col_duration = gtk.TreeViewColumn(_("Duration"))
        col_duration.pack_start(cell_duration)
        col_duration.set_cell_data_func(cell_duration, self._get_duration_data)
        
        self.timersview.append_column(col_duration)
        
        self.scrolledwindow = gtk.ScrolledWindow()
        self.scrolledwindow.set_policy(gtk.POLICY_AUTOMATIC, gtk.POLICY_AUTOMATIC)
        self.scrolledwindow.set_shadow_type(gtk.SHADOW_ETCHED_IN)
        self.scrolledwindow.add(self.timersview)
        self.vbox_main.pack_start(self.scrolledwindow)
        
        self.buttonbox = gtk.HButtonBox()
        self.button_add = gtk.Button(stock=gtk.STOCK_ADD)
        self.button_add.connect("clicked", self._on_button_add_clicked)
        self.buttonbox.pack_start(self.button_add)

        self.button_delete = gtk.Button(stock=gtk.STOCK_DELETE)
        self.button_delete.connect("clicked", self._on_button_delete_clicked)
        self.button_delete.set_sensitive(False)
        self.buttonbox.pack_start(self.button_delete)
        
        self.vbox_main.pack_start(self.buttonbox, False, False, 0)
        
        self.get_timers()
        
        self.show_all()
        
    def set_recorder(self, dev_group):
        self.recorder = dev_group.get_recorder()
        self.recorder.connect("changed", self._on_recorder_changed)
        self.recorder.connect("recording-started", self._set_recording_state, True)
        self.recorder.connect("recording-finished", self._set_recording_state, False)
            
    def get_timers(self):
        def add_timer(timers):
            for timer_id in timers:
                self._add_timer(timer_id)
        self.recorder.get_timers(reply_handler=add_timer, error_handler=global_error_handler)
            
    def _add_timer(self, timer_id):
        start_list, success = self.recorder.get_start_time(timer_id)
        if success:
            starttime = "%04d-%02d-%02d %02d:%02d" % (start_list[0], start_list[1],
                    start_list[2], start_list[3], start_list[4])
            (duration, active, channel, title) = self.recorder.get_all_informations(timer_id)[0][1:]
            
            self.timerslist.append([timer_id, channel, title, starttime, duration, active])

    def _remove_timer(self, timer_id):
        for row in self.timerslist:
            if row[self.COL_ID] == timer_id:
                self.timerslist.remove(row.iter)

    def _on_button_delete_clicked(self, button):
        def delete_timer_callback(success):
            if not success:
                error_dialog = gtk.MessageDialog(parent=self,
                    flags=gtk.DIALOG_MODAL|gtk.DIALOG_DESTROY_WITH_PARENT,
                    type=gtk.MESSAGE_ERROR, buttons=gtk.BUTTONS_OK)
                error_dialog.set_markup(
                    "<big><span weight=\"bold\">%s</span></big>" % _("Timer could not be deleted"))
                error_dialog.run()
                error_dialog.destroy()
    
        model, aiter = self.timersview.get_selection().get_selected()
        if aiter != None:
            timer_id = model[aiter][self.COL_ID]
            if self.recorder.is_timer_active(timer_id):
                dialog = gtk.MessageDialog(parent=self,
                    flags=gtk.DIALOG_MODAL|gtk.DIALOG_DESTROY_WITH_PARENT,
                    type=gtk.MESSAGE_QUESTION, buttons=gtk.BUTTONS_YES_NO)
                dialog.set_markup(
                    "<big><span weight=\"bold\">%s</span></big>" % _("Abort active recording?"))
                dialog.format_secondary_text(
                    _("The timer you selected belongs to a currently active recording.") + " " +
                    _("Deleting this timer will abort the recording."))
                response = dialog.run()
                dialog.destroy()
                if response == gtk.RESPONSE_YES:
                    self.recorder.delete_timer(timer_id,
                        reply_handler=delete_timer_callback,
                        error_handler=global_error_handler)
            else:
                self.recorder.delete_timer(timer_id,
                    reply_handler=delete_timer_callback,
                    error_handler=global_error_handler)
        
    def _on_button_add_clicked(self, button):
        def add_timer_callback(rec_id, success):
            if not success:
                err_dialog = NoTimerCreatedDialog(self)
                err_dialog.run()
                err_dialog.destroy()
    
        dialog = TimerDialog(self, self.device_group)
        response_id = dialog.run()
        if response_id == gtk.RESPONSE_ACCEPT:
            duration = dialog.get_duration()
            start = dialog.get_start_time()
            channel = dialog.get_channel()
            
            self.recorder.add_timer (channel, start[0],
                start[1], start[2], start[3], start[4], duration,
                reply_handler=add_timer_callback,
                error_handler=global_error_handler)
            
        dialog.destroy()
   
    def _on_recorder_changed(self, recorder, timer_id, typeid):
        if recorder == self.recorder:
            if (typeid == 0):
                # Timer added
                self._add_timer(timer_id)
            elif (typeid == 1):
                # Timer deleted
                self._remove_timer(timer_id)
            elif (typeid == 2):
                # Timer changed
                self._remove_timer(timer_id)
                self._add_timer(timer_id)
            
    def _on_timers_selection_changed(self, treeselection):
        model, aiter = treeselection.get_selected()
        if aiter == None:
            self.button_delete.set_sensitive(False)
        else:
            self.button_delete.set_sensitive(True)

    def _set_recording_state(self, recorder, timer_id, state):
        for row in self.timerslist:
            if row[self.COL_ID] == timer_id:
                self.timerslist.set (row.iter, self.COL_ACTIVE, state)
                
    def _get_recording_icon_for_cell(self, column, cell, model, aiter):
        if model[aiter][self.COL_ACTIVE]:
            cell.set_property("stock-id", gtk.STOCK_MEDIA_RECORD)
            
    def _get_duration_data(self, column, cell, model, aiter):
        # We have minutes but need seconds
        duration = model[aiter][self.COL_DURATION] * 60
        duration_str = gnomedvb.seconds_to_time_duration_string(duration)
        cell.set_property("text", duration_str)

