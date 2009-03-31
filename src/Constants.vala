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

namespace DVB.Constants {

    public static const string DBUS_SERVICE = "org.gnome.DVB";
    
    public static const string DBUS_MANAGER_PATH = "/org/gnome/DVB/Manager";
    public static const string DBUS_RECORDINGS_STORE_PATH = "/org/gnome/DVB/RecordingsStore";
    public static const string DBUS_SCANNER_PATH = "/org/gnome/DVB/Scanner/%d/%d";
    public static const string DBUS_RECORDER_PATH = "/org/gnome/DVB/Recorder/%u";
    public static const string DBUS_CHANNEL_LIST_PATH = "/org/gnome/DVB/ChannelList/%u";
    public static const string DBUS_SCHEDULE_PATH = "/org/gnome/DVB/Schedule/%u/%u";
    public static const string DVB_DEVICE_PATH = "/dev/dvb/adapter%u/frontend%u";
}
