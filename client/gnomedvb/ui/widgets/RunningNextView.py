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
from gi.repository import GObject
from gi.repository import Gdk
from gi.repository import Gtk
from gnomedvb import _
from gnomedvb import global_error_handler
from gnomedvb.ui.widgets.RunningNextStore import RunningNextStore
from gnomedvb.ui.widgets.DetailsDialog import DetailsDialog
from gnomedvb.ui.timers.MessageDialogs import TimerFailureDialog, TimerSuccessDialog
       
class RunningNextView(Gtk.TreeView):

    def __init__(self, model):
        GObject.GObject.__init__(self)
        self.set_model(model)
        
        cell_channel = Gtk.CellRendererText()
        col_channel = Gtk.TreeViewColumn(_("Channel"), cell_channel)
        col_channel.add_attribute(cell_channel, "markup",
            RunningNextStore.COL_CHANNEL)
        self.append_column(col_channel)
        col_channel.index = RunningNextStore.COL_CHANNEL
        
        cell_now_start = Gtk.CellRendererText()
        cell_now = Gtk.CellRendererText()
        col_now = Gtk.TreeViewColumn(_("Now"))
        col_now.pack_start(cell_now_start, False)
        col_now.pack_start(cell_now, True)
        col_now.set_cell_data_func(cell_now_start, self._format_time,
            RunningNextStore.COL_RUNNING_START)
        col_now.add_attribute(cell_now, "markup", RunningNextStore.COL_RUNNING)
        col_now.set_property("resizable", True)
        self.append_column(col_now)
        col_now.index = RunningNextStore.COL_RUNNING
        
        cell_next_start = Gtk.CellRendererText()
        cell_next = Gtk.CellRendererText()
        col_next = Gtk.TreeViewColumn(_("Next"))
        col_next.pack_start(cell_next_start, False)
        col_next.pack_start(cell_next, True)
        col_next.set_property("resizable", True)
        col_next.set_cell_data_func(cell_next_start, self._format_time,
            RunningNextStore.COL_NEXT_START)
        col_next.add_attribute(cell_next, "markup", RunningNextStore.COL_NEXT)
        self.append_column(col_next)
        col_next.index = RunningNextStore.COL_NEXT
        
        self.connect("button-press-event", self._on_button_press_event)
    
    def _format_time(self, column, cell, model, aiter, col_id):
        timestamp = model[aiter][col_id]
        if timestamp == 0:
            time_str = ""
        else:
            dt = datetime.datetime.fromtimestamp(timestamp)
            time_str = dt.strftime("%X")
        
        cell.set_property("text", time_str)
        
    def _on_button_press_event(self, treeview, event):
            
        def show_details(proxy, result, user_data):
            data, success = result
            if not success:
                return
            event_id, next_id, name, duration, desc = data
            
            ext_desc, success = schedule.get_extended_description(event_id)
            if success:
                if len(desc) == 0:
                    desc = ext_desc
                else:
                    desc += "\n%s" % ext_desc
            
            dialog = DetailsDialog(self.get_toplevel())
            dialog.set_description(desc)
            dialog.set_title(name)
            dialog.set_duration(duration)
            dialog.set_channel(model[aiter][RunningNextStore.COL_CHANNEL])
            start, success = schedule.get_local_start_timestamp(event_id)
            if success:
                dialog.set_date(start)
            dialog.get_record_button().connect("clicked",
                self._on_record_clicked,
                (devgroup.get_recorder(), event_id, sid,))
            dialog.show()
            dialog.connect("response", lambda d, resp: d.destroy())

        if event.type == getattr(Gdk.EventType, "2BUTTON_PRESS"):
            model, aiter = treeview.get_selection().get_selected()
            if aiter != None:
                pos = treeview.get_path_at_pos(int(event.x), int(event.y))
                if pos != None:
                    col = pos[1]
                    if col.index == RunningNextStore.COL_RUNNING:
                        event_id = model[aiter][RunningNextStore.COL_RUNNING_EVENT]
                    elif col.index == RunningNextStore.COL_NEXT:
                        event_id = model[aiter][RunningNextStore.COL_NEXT_EVENT]
                    else:
                        return
                    
                    devgroup = model.get_device_group()
                    sid = model[aiter][RunningNextStore.COL_SID]
                    schedule = devgroup.get_schedule(sid)
                    if schedule != None:
                        schedule.get_informations(event_id,
                            result_handler=show_details,
                            error_handler=global_error_handler)

    def _on_record_clicked(self, button, data):
        def on_reply(proxy, data, user_data):
            timer_id, success = data
            if success:
                dialog = TimerSuccessDialog(self.get_toplevel())
            else:
                dialog = TimerFailureDialog(self.get_toplevel())
            dialog.run()
            dialog.destroy()

        recorder, event_id, channel_sid = data
        recorder.add_timer_for_epg_event(event_id, channel_sid,
            result_handler=on_reply,
            error_handler=global_error_handler)
        
