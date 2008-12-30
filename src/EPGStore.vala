using GLib;

namespace DVB {

    public interface EPGStore : GLib.Object {
     
        public abstract bool add_or_update_event (Event event, Channel channel);
        public abstract Event? get_event (uint event_id, uint channel_sid);
        public abstract bool remove_event (uint event_id, Channel channel);
        public abstract bool contains_event (Event event, Channel channel);
        public abstract Gee.List<Event> get_events (Channel channel);
        
    }

}
