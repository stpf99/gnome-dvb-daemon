using GLib;

namespace DVB {

    public interface EPGStore : GLib.Object {
     
        private static EPGStore instance;
        
        public abstract bool add_or_update_event (Event event, Channel channel);
        public abstract Event? get_event (uint event_id, uint channel_sid);
        public abstract bool remove_event (uint event_id, Channel channel);
        public abstract bool contains_event (Event event, Channel channel);
        public abstract Gee.List<Event> get_events (Channel channel);
        
        public static weak EPGStore get_instance () {
            // TODO make thread-safe
            if (instance == null) {
                instance = new SqliteEPGStore ();
            }
            return instance;
        }
        
    }

}
