/*
 * Copyright (C) 2009 Sebastian Pölsterl
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
[DBus (name = "org.gnome.UPnP.MediaObject1")]
public interface MediaObject1 : GLib.Object {
    
    public abstract DBus.ObjectPath Parent {
        get;
    }
    
    public abstract string DisplayName {
        get;
    }
}

[DBus (name = "org.gnome.UPnP.MediaContainer1")]
public interface MediaContainer1 : GLib.Object {
    
    public abstract signal void Updated ();
    
    public abstract DBus.ObjectPath[] Items {
        get;
    }
    
    public abstract uint ItemCount {
        get;
    }
    
    public abstract DBus.ObjectPath[] Containers {
        get;
    }
    
    public abstract uint ContainerCount {
        get;
    }
    
}

[DBus (name = "org.gnome.UPnP.MediaItem1")]
public interface MediaItem1 : GLib.Object {
    
    public abstract string[] URLs {
        get;
    }
    
    public abstract string MIMEType {
        get;
    }
    
    public abstract string Type {
        get;
    }
}

