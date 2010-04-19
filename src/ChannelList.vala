/*
 * Copyright (C) 2008,2009 Sebastian Pölsterl
 *
 * This file is part of GNOME DVB Daemon.
 *
 * GNOME DVB Daemon is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * GNOME DVB Daemon is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with GNOME DVB Daemon.  If not, see <http://www.gnu.org/licenses/>.
 */

using GLib;
using Gee;
using DVB.database;
using DVB.database.sqlite;

namespace DVB {

    public class ChannelList : GLib.Object, Iterable<Channel>, IDBusChannelList {
        
        public File? channels_file {get; construct;}
        public uint GroupId {get; set;}
        public int size {
            get { return this.channels.size; }
        }
        
        /**
         * Maps channels' SID to the channels' data
         */
        protected HashMap<uint, Channel> channels;
        
        construct {
            this.channels = new HashMap<uint, Channel> ();
        }
        
        public ChannelList (File? channels=null) {
            base (channels_file: channels);
        }
        
        public Channel? get_channel (uint sid) {
            Channel? val = null;
            lock (this.channels) {
                if (this.channels.contains (sid))
                    val = this.channels.get (sid);
            }
            return val;
        }
        
        public void add (Channel channel) {
            lock (this.channels) {
                this.channels.set (channel.Sid, channel);
            }
        }
        
        public void remove (uint sid) {
            lock (this.channels) {
                this.channels.remove (sid);
            }
        }
        
        public bool contains (uint sid) {
            bool val;
            lock (this.channels) {
                val = this.channels.contains (sid);
            }
            return val;
        }
        
        public void clear () {
            lock (this.channels) {
                this.channels.clear ();
            }
        }
        
        public Type element_type { get { return typeof (Channel); } }
      
        public Iterator<Channel> iterator () {
            return this.channels.values.iterator();
        }
        
        public static ChannelList restore_from_file (File channelsfile,
                AdapterType type, uint group_id) throws Error {
            var reader = new DVB.io.ChannelListReader (channelsfile, type, group_id);
            return reader.read ();
        }
        
        /**
         * @returns: List of channel IDs aka SIDs
         */
        public uint[] GetChannels () throws DBus.Error {
            uint[] ids = new uint[this.size];
            int i=0;
            lock (this.channels) {
                foreach (uint id in this.channels.keys) {
                    ids[i] = id;
                    i++;
                }
            }
            
            return ids;
        }
        
        /**
         * @returns: List of channel IDs aka SIDs of radio channels
         */
        public uint[] GetRadioChannels () throws DBus.Error {
            SList<uint> radio_channels = new SList<uint> ();
            lock (this.channels) {
                foreach (uint id in this.channels.keys) {
                    Channel chan = this.channels.get (id);
                    if (chan.VideoPID == 0)
                        radio_channels.prepend (id);
                }
            }
            radio_channels.reverse ();
            
            uint[] ids = new uint[radio_channels.length ()];
            for (int i=0; i<radio_channels.length (); i++) {
                ids[i] = radio_channels.nth_data (i);
            }
            
            return ids;
        }
        
        /**
         * @returns: List of channel IDs aka SIDs of TV channels
         */
        public uint[] GetTVChannels () throws DBus.Error {
            SList<uint> video_channels = new SList<uint> ();
            lock (this.channels) {
                foreach (uint id in this.channels.keys) {
                    Channel chan = this.channels.get (id);
                    if (!chan.is_radio ())
                        video_channels.prepend (id);
                }
            }
            video_channels.reverse ();
            
            uint[] ids = new uint[video_channels.length ()];
            for (int i=0; i<video_channels.length (); i++) {
                ids[i] = video_channels.nth_data (i);
            }
            
            return ids;
        }
        
        /**
         * @channel_id: ID of channel
         * @channel_name: Name of channel if channel with id exists
         * otherwise an empty string
         * @returns: TRUE on success
         */
        public bool GetChannelName (uint channel_id, out string channel_name)
                throws DBus.Error
        {
            bool ret = false;
            string val = "";
            
            lock (this.channels) {
                if (this.channels.contains (channel_id)) {
                    string name = this.channels.get (channel_id).Name;
                    val = (name == null) ? "" : name;
                    ret = true;
                }
            }
            channel_name = val;
            
            return ret;
        }
        
        /**
         * @channel_id: ID of channel
         * @network: Name of network the channel belongs to
         * if the channel with id exists, otherwise an empty
         * string
         * @returns: TRUE on success
         */
        public bool GetChannelNetwork (uint channel_id, out string network)
                throws DBus.Error {
            string val = "";
            bool ret = false;
            lock (this.channels) {
                if (this.channels.contains (channel_id)) {
                    string tmp = this.channels.get (channel_id).Network;
                    val = (tmp == null) ? "" : tmp;
                    ret = true;
                }
            }
            network = val;
            return ret;
        }
        
        /**
         * @channel_id: ID of channel
         * @radio: Whether the channel is a radio channel or not
         * @returns: TRUE on success
         */
        public bool IsRadioChannel (uint channel_id, out bool radio)
                throws DBus.Error
        {
            bool val = false;
            bool ret = false;
            lock (this.channels) {
                if (this.channels.contains (channel_id)) {
                    val = this.channels.get (channel_id).is_radio ();
                    ret = true;
                }
            }
            radio = val;
            return ret;
        }
        
        /**
         * @channel_id: ID of channel
         * @url: URL to watch the channel
         * @returns: TRUE on success
         */
        public bool GetChannelURL (uint channel_id, out string url)
                throws DBus.Error
        {
            Channel channel = null;

            lock (this.channels) {
                if (this.channels.contains (channel_id)) {
                    channel = this.channels.get (channel_id);
                }
            }

            if (channel == null) {
                url = "";
                return false;
            } else {
                url = channel.URL;
                return true;
            }
        }
        
        public ChannelInfo[] GetChannelInfos () throws DBus.Error {
            ChannelInfo[] channels = new ChannelInfo[this.channels.size];
            int i = 0;
            lock (this.channels) {
                foreach (uint id in this.channels.keys) {
                    Channel channel = this.channels.get (id);
                    ChannelInfo chan_info = ChannelInfo();
                    chan_info.id = id;
                    chan_info.name = channel.Name;
                    chan_info.is_radio = channel.is_radio ();
                    channels[i] = chan_info;
                    i++;
                }
            }
            return channels;
        }

		/**
         * @channel_group_id: ID of the ChannelGroup
         * @returns: TRUE on success
         */
		public bool GetChannelsOfGroup (int channel_group_id,
                out uint[] channel_ids) throws DBus.Error
        {
            ConfigStore config = Factory.get_config_store ();
            Gee.List<uint> channels;
            try {
                channels = config.get_channels_of_group (this.GroupId,
                    channel_group_id);
            } catch (SqlError e) {
                critical ("%s", e.message);
                return false;
            }

            channel_ids = new uint[channels.size];
            for (int i=0; i<channel_ids.length; i++) {
                channel_ids[i] = channels.get (i);
            }

            return true;
        }

		/**
         * @channel_id: ID of channel
	     * @channel_group_id: ID of the ChannelGroup
         * @returns: TRUE on success
         */
		public bool AddChannelToGroup (uint channel_id, int channel_group_id)
                throws DBus.Error
        {
            ConfigStore config = Factory.get_config_store ();
            Channel? chan = this.get_channel (channel_id);
            if (chan == null)
                return false;

            bool ret;
            try {
                ret = config.add_channel_to_group (chan, channel_group_id);
            } catch (SqlError e) {
                critical ("%s", e.message);
                ret = false;
            }
            return ret;
        }

 		/**
		 * @channel_id: ID of channel
	     * @channel_group_id: ID of the ChannelGroup
         * @returns: TRUE on success
         */       
		public bool RemoveChannelFromGroup (uint channel_id,
                int channel_group_id) throws DBus.Error
        {
            ConfigStore config = Factory.get_config_store ();
            Channel? chan = this.get_channel (channel_id);
            if (chan == null)
                return false;

            bool ret;
            try {
                ret = config.remove_channel_from_group (chan, channel_group_id);
            } catch (SqlError e) {
                critical ("%s", e.message);
                ret = false;
            }
            return ret;
        }
    }

}
