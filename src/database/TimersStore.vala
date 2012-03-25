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

namespace DVB.database {

    public interface TimersStore : GLib.Object {
        
        public abstract Gee.List<Timer> get_all_timers_of_device_group (DeviceGroup dev) throws SqlError;
        public abstract bool add_timer_to_device_group (Timer timer, DeviceGroup dev) throws SqlError;
        public abstract bool remove_timer_from_device_group (uint timer_id, DeviceGroup dev) throws SqlError;
        public abstract bool remove_all_timers_from_device_group (uint group_id) throws SqlError;
        public abstract bool update_timer (Timer timer, DeviceGroup dev) throws SqlError;

    }

}
