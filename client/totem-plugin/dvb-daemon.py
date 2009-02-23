import pygtk
pygtk.require("2.0")
import gtk
import pygst
pygst.require("0.10")

import totem
import gnomedvb

from gnomedvb import global_error_handler
from gnomedvb.ui.widgets.ChannelsStore import ChannelsTreeStore
from gnomedvb.ui.widgets.ChannelsView import ChannelsView

class DVBDaemonPlugin(totem.Plugin):

    REC_GROUP_ID = -1

    def __init__ (self):
        totem.Plugin.__init__(self)
        
        self.totem_object = None
        
        self.channels = ChannelsTreeStore()
        
        self.channels_view = ChannelsView(self.channels, ChannelsTreeStore.COL_NAME)
        self.channels_view.connect("button-press-event", self._on_channel_selected)
        
        self.scrolledchannels = gtk.ScrolledWindow()
        self.scrolledchannels.set_policy(gtk.POLICY_AUTOMATIC, gtk.POLICY_AUTOMATIC)
        self.scrolledchannels.set_shadow_type(gtk.SHADOW_ETCHED_IN)
        self.scrolledchannels.add(self.channels_view)
        
        # Add recordings
        self.rec_iter = self.channels.append(None, [self.REC_GROUP_ID, _("Recordings"), 0])
        self.recstore = gnomedvb.DVBRecordingsStoreClient()
        self.recstore.connect("changed", self._on_recstore_changed)
        add_rec = lambda recs: [self._add_recording(rid) for rid in recs]
        self.recstore.get_recordings(reply_handler=add_rec, error_handler=global_error_handler)
        
        self.scrolledchannels.show_all()

    def activate (self, totem_object):
        totem_object.add_sidebar_page ("dvb-daemon", _("DVB"), self.scrolledchannels)
        self.totem_object = totem_object

    def deactivate (self, totem_object):
        totem_object.remove_sidebar_page ("dvb-daemon")
        self.totem_object = None
        
    def _on_channel_selected(self, treeview, event):
        if event.type == gtk.gdk._2BUTTON_PRESS:
            model, aiter = treeview.get_selection().get_selected()
            if aiter != None:
                group_id = model[aiter][model.COL_GROUP_ID]
                sid = model[aiter][model.COL_SID]
                if group_id == self.REC_GROUP_ID:
                    url = self.recstore.get_location(sid)
                else:
                    channellist = gnomedvb.DVBChannelListClient(group_id)
                    url = channellist.get_channel_url(sid)
                self.totem_object.action_remote(totem.REMOTE_COMMAND_REPLACE, url)
                self.totem_object.action_remote(totem.REMOTE_COMMAND_PLAY, url)
                
    def _add_recording(self, rid):
        name = self.recstore.get_name(rid)
        if name == "":
            name = _("Recording %d") % rid
        self.channels.append(self.rec_iter, [self.REC_GROUP_ID, name, rid])
                
    def _on_recstore_changed(self, recstore, rec_id, change_type):
        if change_type == 0:
            # Added
            self._add_recording(rec_id)
        elif change_type == 1:
            # Deleted
            child_iter = self.channels.iter_children(self.rec_iter)
            while child_iter != None:
                sid = self.channels[child_iter][self.channels.COL_SID]
                if sid == rec_id:
                    self.channels.remove(child_iter)
                    break
                child_iter = self.channels.iter_next(child_iter) 
                
