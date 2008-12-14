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
