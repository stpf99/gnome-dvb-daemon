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

namespace DVB {

    public interface ConfigStore : GLib.Object {
        
        public abstract Gee.List<DeviceGroup> get_all_device_groups ();
        public abstract bool add_device_group (DeviceGroup dev_group);
        public abstract bool remove_device_group (DeviceGroup devgroup);
        public abstract bool add_device_to_group (Device dev, DeviceGroup devgroup);
        public abstract bool remove_device_from_group (Device dev, DeviceGroup devgroup);
        public abstract bool update_from_group (DeviceGroup devgroup);
        
    }

}
