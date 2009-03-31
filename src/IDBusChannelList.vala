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

	[DBus (name = "org.gnome.DVB.ChannelList")]
	public interface IDBusChannelList : GLib.Object {
	
		/**
         * @type: 0: added, 1: deleted, 2: updated
         */
        public abstract signal void changed (uint channel_id, uint type);
        
        /**
         * @returns: List of channel IDs aka SIDs of all channels
         */
        public abstract uint[] GetChannels ();
        
        /**
         * @returns: List of channel IDs aka SIDs of radio channels
         */
        public abstract uint[] GetRadioChannels ();
        
        /**
         * @returns: List of channel IDs aka SIDs of TV channels
         */
        public abstract uint[] GetTVChannels ();
        
        /**
         * @channel_id: ID of channel
         * @returns: Name of channel if channel with id exists
         * otherwise an empty string
         */
        public abstract string GetChannelName (uint channel_id);
        
        /**
         * @channel_id: ID of channel
         * @returns: Name of network the channel belongs to
         * if the channel with id exists, otherwise an empty
         * string
         */
        public abstract string GetChannelNetwork (uint channel_id);
        
        /**
         * @channel_id: ID of channel
         * @returns: Whether the channel is a radio channel or not
         */
        public abstract bool IsRadioChannel (uint channel_id);
        
        /**
         * @channel_id: ID of channel
         * @returns: URL to watch the channel
         */
        public abstract string GetChannelURL (uint channel_id);
        
	}

}
