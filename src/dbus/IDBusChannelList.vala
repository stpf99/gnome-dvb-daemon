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

namespace DVB {

	public struct ChannelInfo {
		public uint id;
		public string name;
		public bool is_radio;
	}

	[DBus (name = "org.gnome.DVB.ChannelList")]
	public interface IDBusChannelList : GLib.Object {
	
		/**
         * @type: 0: added, 1: deleted, 2: updated
         */
        public abstract signal void changed (uint channel_id, uint type);
        
        /**
         * @returns: List of channel IDs aka SIDs of all channels
         */
        public abstract uint[] GetChannels () throws DBus.Error;
        
        /**
         * @returns: List of channel IDs aka SIDs of radio channels
         */
        public abstract uint[] GetRadioChannels () throws DBus.Error;
        
        /**
         * @returns: List of channel IDs aka SIDs of TV channels
         */
        public abstract uint[] GetTVChannels () throws DBus.Error;
        
        /**
         * @channel_id: ID of channel
         * @channel_name: Name of channel if channel with id exists
         * otherwise an empty string
         * @returns: TRUE on success
         */
        public abstract bool GetChannelName (uint channel_id, out string channel_name) throws DBus.Error;
        
        /**
         * @channel_id: ID of channel
         * @network: Name of network the channel belongs to
         * if the channel with id exists, otherwise an empty
         * string
         * @returns: TRUE on success
         */
        public abstract bool GetChannelNetwork (uint channel_id, out string network) throws DBus.Error;
        
        /**
         * @channel_id: ID of channel
         * @radio: Whether the channel is a radio channel or not
         * @returns: TRUE on success
         */
        public abstract bool IsRadioChannel (uint channel_id, out bool radio) throws DBus.Error;
        
        /**
         * @channel_id: ID of channel
         * @url: URL to watch the channel
         * @returns: TRUE on success
         */
        public abstract bool GetChannelURL (uint channel_id, out string url) throws DBus.Error;
        
        public abstract ChannelInfo[] GetChannelInfos () throws DBus.Error;

		/**
         * @channel_group_id: ID of the ChannelGroup
         * @returns: TRUE on success
         */
		public abstract bool GetChannelsOfGroup (int channel_group_id,
			out uint[] channel_ids) throws DBus.Error;

		/**
         * @channel_id: ID of channel
	     * @channel_group_id: ID of the ChannelGroup
         * @returns: TRUE on success
         */
		public abstract bool AddChannelToGroup (uint channel_id, int channel_group_id) throws DBus.Error;

 		/**
		 * @channel_id: ID of channel
	     * @channel_group_id: ID of the ChannelGroup
         * @returns: TRUE on success
         */       
		public abstract bool RemoveChannelFromGroup (uint channel_id, int channel_group_id) throws DBus.Error;
	}

}
