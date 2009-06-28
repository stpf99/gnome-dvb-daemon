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

    [DBus (name = "org.gnome.DVB.Manager")]
    public interface IDBusManager : GLib.Object {
    
        public abstract signal void group_added (uint group_id);
        public abstract signal void group_removed (uint group_id);
         
        /**
         * @adapter: Number of the device's adapter
         * @frontend: Number of the device's frontend
         * @returns: Object path and interface to the scanner service
         *
         * Get the object path of the channel scanner for this device.
         */
        public abstract string[] GetScannerForDevice (uint adapter, uint frontend);
        
        /**
         * @returns: Device groups' DBus path
         */
        public abstract DBus.ObjectPath[] GetRegisteredDeviceGroups ();
        
        /**
         * @group_id: A group ID
         * @returns: Device group's DBus path
         */
        public abstract DBus.ObjectPath GetDeviceGroup (uint group_id);
        
        /**
         * @adapter: Number of the device's adapter
         * @frontend: Number of the device's frontend
         * @channels_conf: Path to channels.conf for this device
         * @recordings_dir: Path where the recordings should be stored
         * @name: Name of group
         * @returns: TRUE when the device has been registered successfully
         *
         * Creates a new DeviceGroup and new DVB device whereas the
         * DVB device is the reference device of this group (i.e.
         * all other devices of this group will inherit the settings
         * of the reference device).
         */
        public abstract bool AddDeviceToNewGroup (uint adapter, uint frontend,
                string channels_conf, string recordings_dir, string name);

        /**
         * @adapter: Adapter of device
         * @frontend: Frontend of device
         * @returns: The name of the device or "Unknown"
         *
         * The device must be part of group, otherwise "Unknown"
         * is returned.
         */
        public abstract string GetNameOfRegisteredDevice (uint adapter, uint frontend);
        
        /**
         * @returns: the numner of configured device groups
         */
        public abstract int GetDeviceGroupSize ();
    }

}
