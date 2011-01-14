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
#ifndef __CSTUFF_H__
#define __CSTUFF_H__

#include <gst/gst.h>

struct net_adapter {
    gchar *name;
    gchar *address;
};

G_GNUC_INTERNAL GList*
get_adapters ();

G_GNUC_INTERNAL void
net_adapter_free (struct net_adapter *na);

G_GNUC_INTERNAL guint
gst_bus_add_watch_context   (GstBus * bus,
                             GstBusFunc func,
                             gpointer user_data,
                             GMainContext * context);

G_GNUC_INTERNAL void
program_log (const char *format, ...);

#endif /* __CSTUFF_H__ */
