using GLib;

namespace DVB {

    [Compact]
    public class Factory {

        private static DVB.SqliteConfigTimersStore store;
        private static StaticRecMutex store_mutex = StaticRecMutex ();
        private static DVB.EPGStore epgstore;
        private static StaticRecMutex epgstore_mutex = StaticRecMutex ();
        
        public static weak DVB.TimersStore get_timers_store () {
        	store_mutex.lock ();
        	if (store == null) {
        		store = new DVB.SqliteConfigTimersStore ();
        	}
        	store_mutex.unlock ();
        	return store;
        }
        
        public static weak DVB.ConfigStore get_config_store () {
        	store_mutex.lock ();
        	if (store == null) {
        		store = new DVB.SqliteConfigTimersStore ();
        	}
        	store_mutex.unlock ();
        	return store;
        }
        
        public static weak DVB.EPGStore get_epg_store () {
        	epgstore_mutex.lock ();
        	if (epgstore == null) {
        		epgstore = new DVB.SqliteEPGStore ();
        	}
        	epgstore_mutex.unlock ();
        	return epgstore;
        }
        
        public static void shutdown () {
            store_mutex.lock ();
            store = null;
            store_mutex.unlock ();
            
            epgstore_mutex.lock ();
            epgstore = null;
            epgstore_mutex.unlock ();
        }
        
    }
    
}
