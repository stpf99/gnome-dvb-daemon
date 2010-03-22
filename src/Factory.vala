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
using DVB.database;
using DVB.database.sqlite;

namespace DVB {

    [Compact]
    public class Factory {

        private static SqliteConfigTimersStore store;
        private static StaticRecMutex store_mutex = StaticRecMutex ();
        private static SqliteEPGStore epgstore;
        private static StaticRecMutex epgstore_mutex = StaticRecMutex ();
        private static DVB.Settings settings;
        private static StaticRecMutex settings_mutex = StaticRecMutex ();
        
        public static unowned TimersStore get_timers_store () {
        	store_mutex.lock ();
        	if (store == null) {
        		store = new SqliteConfigTimersStore ();
                try {
                    store.open ();
                } catch (SqlError e) {
                    critical ("%s", e.message);
                    store = null;
                }
        	}
        	store_mutex.unlock ();
        	return store;
        }
        
        public static unowned ConfigStore get_config_store () {
        	store_mutex.lock ();
        	if (store == null) {
        		store = new SqliteConfigTimersStore ();
                try {
                    store.open ();
                } catch (SqlError e) {
                    critical ("%s", e.message);
                    store = null;
                }
        	}
        	store_mutex.unlock ();
        	return store;
        }
        
        public static unowned EPGStore get_epg_store () {
        	epgstore_mutex.lock ();
        	if (epgstore == null) {
        		epgstore = new SqliteEPGStore ();
                try {
                    epgstore.open ();
                } catch (SqlError e) {
                    critical ("%s", e.message);
                    epgstore = null;
                }
        	}
        	epgstore_mutex.unlock ();
        	return epgstore;
        }
        
        public static unowned DVB.Settings get_settings () {
            settings_mutex.lock ();
            if (settings == null) {
                settings = new DVB.Settings ();
                settings.load ();
            }
            settings_mutex.unlock ();
            return settings;
        }
        
        public static void shutdown () {
            store_mutex.lock ();
            store = null;
            store_mutex.unlock ();
            
            epgstore_mutex.lock ();
            epgstore = null;
            epgstore_mutex.unlock ();
            
            settings_mutex.lock ();
            if (settings != null) settings.save ();
            settings = null;
            settings_mutex.unlock ();
        }
        
    }
    
}
