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
using DVB.Logging;

namespace DVB {

    public class Factory : GLib.Object {

        private static Logger log = LogManager.getLogManager().getDefaultLogger();

        private static SqliteConfigTimersStore store;
        private static SqliteEPGStore epgstore;
        private static DVB.Settings settings;

        public TimersStore get_timers_store () {
            lock(store) {
        	if (store == null) {
        		store = new SqliteConfigTimersStore ();
                try {
                    store.open ();
                } catch (SqlError e) {
                    log.error ("%s", e.message);
                    store = null;
                }
        	}
            }
        	return store;
        }

        public ConfigStore get_config_store () {
            lock(store) {
        	if (store == null) {
        		store = new SqliteConfigTimersStore ();
                try {
                    store.open ();
                } catch (SqlError e) {
                    log.error ("%s", e.message);
                    store = null;
                }
        	}
            }
        	return store;
        }

        public EPGStore get_epg_store () {
            lock (epgstore) {
        	if (epgstore == null) {
        		epgstore = new SqliteEPGStore ();
                try {
                    epgstore.open ();
                } catch (SqlError e) {
                    log.error ("%s", e.message);
                    epgstore = null;
                }
        	}
            }
        	return epgstore;
        }

        public DVB.Settings get_settings () {
            lock(settings) {
            if (settings == null) {
                settings = new DVB.Settings ();
                settings.load ();
            }
            }
            return settings;
        }

        public void shutdown () {
            lock(settings) {
            if (settings != null) settings.save ();
            }
        }

    }

}
