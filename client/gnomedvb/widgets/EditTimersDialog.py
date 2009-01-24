# -*- coding: utf-8 -*-
import gtk
from gettext import gettext as _
import gnomedvb
from gnomedvb.timers.ui.TimerDialog import TimerDialog

class EditTimersDialog(gtk.Dialog):

    (COL_ID,
    COL_CHANNEL,
    COL_START,
    COL_DURATION,
    COL_ACTIVE,) = range(5)
    
    def __init__(self, device_group, parent=None):
        """
        @param device_group: ID of device group
        @type device_group: int
        @param parent: Parent window
        @type parent: gtk.Window
        """
        gtk.Dialog.__init__(self, title=_("Scheduled Recordings"),
            parent=parent,
            flags=gtk.DIALOG_MODAL | gtk.DIALOG_DESTROY_WITH_PARENT,
            buttons=(gtk.STOCK_CLOSE, gtk.RESPONSE_CLOSE))
        
        self.device_group = device_group
        self.set_recorder(device_group)
        
        self.vbox.set_spacing(6)
        self.set_size_request(350, 400)
        
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
        col_duration = gtk.TreeViewColumn(_("Duration"))
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
        self.buttonbox.pack_start(self.button_add)

        self.button_delete = gtk.Button(stock=gtk.STOCK_DELETE)
        self.button_delete.connect("clicked", self._on_button_delete_clicked)
        self.button_delete.set_sensitive(False)
        self.buttonbox.pack_start(self.button_delete)
        
        self.vbox.pack_start(self.buttonbox, False, False, 0)
        
        self.get_timers()
        
        self.show_all()
        
    def set_recorder(self, group_id):
        self.recorder = gnomedvb.DVBRecorderClient(group_id)
        self.recorder.connect("changed", self._on_recorder_changed)
        self.recorder.connect("recording-started", self._set_recording_state, True)
        self.recorder.connect("recording-finished", self._set_recording_state, False)
            
    def get_timers(self):
        for timer_id in self.recorder.get_timers():
            self._add_timer(timer_id)
            
    def _add_timer(self, timer_id):
        start_list = self.recorder.get_start_time(timer_id)
        starttime = "%04d-%02d-%02d %02d:%02d" % (start_list[0], start_list[1],
                start_list[2], start_list[3], start_list[4])
        duration = self.recorder.get_duration(timer_id)
        channel = self.recorder.get_channel_name(timer_id)
        active = self.recorder.is_timer_active(timer_id)
        
        self.timerslist.append([timer_id, channel, starttime, duration, active])

    def _remove_timer(self, timer_id):
        for row in self.timerslist:
            if row[self.COL_ID] == timer_id:
                self.timerslist.remove(row.iter)

    def _on_button_delete_clicked(self, button):
        model, aiter = self.timersview.get_selection().get_selected()
        if aiter != None:
            timer_id = model[aiter][self.COL_ID]
            if self.recorder.is_timer_active(timer_id):
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
                    if not self.recorder.delete_timer(timer_id):
                        error_dialog = gtk.MessageDialog(parent=self,
                            flags=gtk.DIALOG_MODAL|gtk.DIALOG_DESTROY_WITH_PARENT,
                            type=gtk.MESSAGE_ERROR, buttons=gtk.BUTTONS_YES_NO)
                        error_dialog.set_markup(_("<big><span weight=\"bold\">Timer could not be deleted</big></span>"))
                        error_dialog.run()
                        error_dialog.destroy()
            else:
                self.recorder.delete_timer(timer_id)
        
    def _on_button_add_clicked(self, button):
        d = TimerDialog(self, self.device_group)
        d.run()
        d.destroy()
     
    def _on_recorderscombo_changed(self, combo):
        self.timerslist.clear()
        self.get_timers(self._get_active_device_group())
        self.button_add.set_sensitive(True)
        
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
    
