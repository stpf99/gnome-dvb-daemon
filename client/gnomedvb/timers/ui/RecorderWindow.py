# -*- coding: utf-8 -*-
import gnomedvb
import gtk
from gettext import gettext as _
from TimerDialog import TimerDialog

class RecorderWindow(gtk.Window):

    (COL_ID,
    COL_CHANNEL,
    COL_START,
    COL_DURATION,
    COL_ACTIVE,) = range(5)
    
    (COL_NAME,
    COL_PATH,) = range(2)

    def __init__(self):
        gtk.Window.__init__(self)
        
        self.recorders = {}
        
        self.set_title(_("Schedule Recordings"))
        self.set_size_request(350, 400)
        self.set_border_width(3)
        self.connect("delete-event", gtk.main_quit)
        self.connect("destroy-event", gtk.main_quit)
        
        self.vbox = gtk.VBox(spacing=6)
        self.add(self.vbox)
        
        recorders_ali = gtk.Alignment(0, 0.5)
        self.vbox.pack_start(recorders_ali, False)
        
        recorders_label = gtk.Label()
        recorders_label.set_markup(_("<b>Choose device group:</b>"))
        recorders_ali.add(recorders_label)
        
        self.recorderslist = gtk.ListStore(str, int)
        
        self.recorderscombo = gtk.ComboBox(self.recorderslist)
        self.recorderscombo.connect("changed", self._on_recorderscombo_changed)
        
        cell_adapter = gtk.CellRendererText()
        self.recorderscombo.pack_start(cell_adapter)
        self.recorderscombo.add_attribute(cell_adapter, "text", self.COL_NAME)
        self.vbox.pack_start(self.recorderscombo, False)
        
        timers_ali = gtk.Alignment(0, 0.5)
        self.vbox.pack_start(timers_ali, False)
        
        timers_label = gtk.Label()
        timers_label.set_markup(_("<b>Scheduled recordings:</b>"))
        timers_ali.add(timers_label)
        
        self.timerslist = gtk.ListStore(int, str, str, int, bool)
        self.timerslist.set_sort_column_id(self.COL_START, gtk.SORT_ASCENDING)
        
        self.timersview = gtk.TreeView(self.timerslist)
        self.timersview.get_selection().connect("changed",
            self._on_timers_selection_changed)
        
        cell_rec = gtk.CellRendererPixbuf()
        col_rec = gtk.TreeViewColumn()
        col_rec.pack_start(cell_rec)
        col_rec.set_cell_data_func(cell_rec, self._get_recording_icon_for_cell)
        col_rec.add_attribute(cell_rec, "stock-id", self.COL_ACTIVE)
        
        self.timersview.append_column(col_rec)
         
        cell_id = gtk.CellRendererText()
        col_id = gtk.TreeViewColumn(_("ID"))
        col_id.pack_start(cell_id)
        col_id.add_attribute(cell_id, "text", self.COL_ID)
        
        self.timersview.append_column(col_id)
        
        cell_channel = gtk.CellRendererText()
        col_channel = gtk.TreeViewColumn(_("Channel"))
        col_channel.pack_start(cell_channel)
        col_channel.add_attribute(cell_channel, "text", self.COL_CHANNEL)
        
        self.timersview.append_column(col_channel)
        
        cell_starttime = gtk.CellRendererText()
        col_starttime = gtk.TreeViewColumn(_("Start time"))
        col_starttime.pack_start(cell_starttime)
        col_starttime.add_attribute(cell_starttime, "text", self.COL_START)
        
        self.timersview.append_column(col_starttime)
        
        cell_duration = gtk.CellRendererText()
        col_duration = gtk.TreeViewColumn(_("Duration in minutes"))
        col_duration.pack_start(cell_duration)
        col_duration.add_attribute(cell_duration, "text", self.COL_DURATION )
        
        self.timersview.append_column(col_duration)
        
        self.scrolledwindow = gtk.ScrolledWindow()
        self.scrolledwindow.set_policy(gtk.POLICY_AUTOMATIC, gtk.POLICY_AUTOMATIC)
        self.scrolledwindow.set_shadow_type(gtk.SHADOW_ETCHED_IN)
        self.scrolledwindow.add(self.timersview)
        self.vbox.pack_start(self.scrolledwindow)
        
        self.buttonbox = gtk.HButtonBox()
        self.button_add = gtk.Button(stock=gtk.STOCK_ADD)
        self.button_add.connect("clicked", self._on_button_add_clicked)
        self.button_add.set_sensitive(False)
        self.buttonbox.pack_start(self.button_add)

        self.button_delete = gtk.Button(stock=gtk.STOCK_DELETE)
        self.button_delete.connect("clicked", self._on_button_delete_clicked)
        self.button_delete.set_sensitive(False)
        self.buttonbox.pack_start(self.button_delete)
        
        self.vbox.pack_start(self.buttonbox, False, False, 0)
        
        self.get_device_groups()
        
    def get_device_groups(self):
        manager = gnomedvb.DVBManagerClient()
        
        for group_id in manager.get_registered_device_groups():
            group_name = manager.get_device_group_name(group_id)
            if group_name == "":
                group_name = _("Group %d") % group_id
            self.recorderslist.append([group_name, group_id])
            self.recorders[group_id] = gnomedvb.DVBRecorderClient(group_id)
            self.recorders[group_id].connect("changed", self._on_recorder_changed)
            self.recorders[group_id].connect("recording-started", self._set_recording_state, True)
            self.recorders[group_id].connect("recording-finished", self._set_recording_state, False)
            
    def get_timers(self, recorder_path):
        rec = self.recorders[recorder_path]
        
        for timer_id in rec.get_timers():
            self._add_timer(rec, timer_id)
            
    def _add_timer(self, rec, timer_id):
        start_list = rec.get_start_time(timer_id)
        starttime = "%04d-%02d-%02d %02d:%02d" % (start_list[0], start_list[1],
                start_list[2], start_list[3], start_list[4])
        duration = rec.get_duration(timer_id)
        channel = rec.get_channel_name(timer_id)
        active = rec.is_timer_active(timer_id)
        
        self.timerslist.append([timer_id, channel, starttime, duration, active])

    def _remove_timer(self, timer_id):
        for row in self.timerslist:
            if row[self.COL_ID] == timer_id:
                self.timerslist.remove(row.iter)

    def _on_button_delete_clicked(self, button):
        model, aiter = self.timersview.get_selection().get_selected()
        if aiter != None:
            rec = self.recorders[self._get_active_device_group()]
            timer_id = model[aiter][self.COL_ID]
            if rec.is_timer_active(timer_id):
                dialog = gtk.MessageDialog(parent=self,
                    flags=gtk.DIALOG_MODAL|gtk.DIALOG_DESTROY_WITH_PARENT,
                    type=gtk.MESSAGE_QUESTION, buttons=gtk.BUTTONS_YES_NO)
                dialog.set_markup(_("<big><span weight=\"bold\">Abort active recording?</span></big>"))
                dialog.format_secondary_text(
                    _("The timer you selected belongs to a currently active recording.") + " " +
                    _("Deleting this timer will abort the recording."))
                response = dialog.run()
                dialog.destroy()
                if response == gtk.RESPONSE_YES:
                    if not rec.delete_timer(timer_id):
                        error_dialog = gtk.MessageDialog(parent=self,
                            flags=gtk.DIALOG_MODAL|gtk.DIALOG_DESTROY_WITH_PARENT,
                            type=gtk.MESSAGE_ERROR, buttons=gtk.BUTTONS_YES_NO)
                        error_dialog.set_markup(_("<big><span weight=\"bold\">Timer could not be deleted</big></span>"))
                        error_dialog.run()
                        error_dialog.destroy()
            else:
                rec.delete_timer(timer_id)
        
    def _on_button_add_clicked(self, button):   
        device_group = self._get_active_device_group()
        
        d = TimerDialog(self, device_group)
        if (d.run() == gtk.RESPONSE_ACCEPT):
            
            duration = d.get_duration()
            start = d.get_start_time()
            channel = d.get_channel()
            
            rec = self.recorders[device_group]
            rec_id = rec.add_timer (channel, start[0], start[1], start[2],
                start[3], start[4], duration)
              
            if rec_id == 0:
                dialog = gtk.MessageDialog(parent=d,
                    flags=gtk.DIALOG_MODAL|gtk.DIALOG_DESTROY_WITH_PARENT,
                    type=gtk.MESSAGE_ERROR, buttons=gtk.BUTTONS_OK)
                dialog.set_markup (_("<big><span weight=\"bold\">Timer could not be created</span></big>"))
                dialog.format_secondary_text(
                    _("Make sure that the timer doesn't conflict with another one and doesn't start in the past.")
                )
                dialog.run()
                dialog.destroy()
            
        d.destroy()
        
    def _get_active_device_group(self):
        aiter = self.recorderscombo.get_active_iter()
        return self.recorderslist[aiter][self.COL_PATH]
        
    def _on_recorderscombo_changed(self, combo):
        self.timerslist.clear()
        self.get_timers(self._get_active_device_group())
        self.button_add.set_sensitive(True)
        
    def _on_recorder_changed(self, recorder, timer_id, typeid):
        group_id = self._get_active_device_group()
        if recorder == self.recorders[group_id]:
            if (typeid == 0):
                # Timer added
                self._add_timer(recorder, timer_id)
            elif (typeid == 1):
                # Timer deleted
                self._remove_timer(timer_id)
            elif (typeid == 2):
                # Timer changed
                self._remove_timer(timer_id)
                self._add_timer(recorder, timer_id)
            
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
    
