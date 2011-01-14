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
#include "cstuff.h"
#include <unistd.h>
#include <sys/types.h>
#include <ifaddrs.h>
#include <sys/socket.h>
#include <netdb.h>
#include <string.h>

guint
gst_bus_add_watch_context (GstBus * bus, GstBusFunc func,
    gpointer user_data, GMainContext * context)
{
  GSource *source;
  guint id;

  source = gst_bus_create_watch (bus);

  g_source_set_callback (source, (GSourceFunc) func, user_data, NULL);

  id = g_source_attach (source, NULL);
  g_source_unref (source);

  return id;
}

void
program_log (const char *format, ...)
{
        va_list args;
        char *formatted, *str;

        va_start (args, format);
        formatted = g_strdup_vprintf (format, args);
        va_end (args);

        str = g_strdup_printf ("MARK: %s: %s", g_get_prgname(), formatted);
        g_free (formatted);

        access (str, F_OK);
        g_free (str);
}

GList*
get_adapters ()
{
    struct ifaddrs *ifap, *iter;
    GList *list = NULL;
    struct net_adapter *na;
    int family, errnum;
    char host[NI_MAXHOST];

    errnum = getifaddrs (&ifap);
    if (errnum == -1) {
        g_critical ("getifaddrs() failed: %s", strerror (errnum));
        return NULL;
    }

    for (iter = ifap; iter; iter = iter->ifa_next) {
        family = iter->ifa_addr->sa_family;
        if (family == AF_INET) { /* IPv4 only */
            errnum = getnameinfo (iter->ifa_addr, sizeof(struct sockaddr_in),
                host, NI_MAXHOST, NULL, 0, NI_NUMERICHOST);
            if (errnum != 0) {
                g_critical ("getnameinfo() failed for %s: %s", iter->ifa_name,
                    gai_strerror (errnum));
            } else {
                na = g_new (struct net_adapter, 1);
                na->name = g_strdup (iter->ifa_name);
                na->address = g_strdup (host);

                list = g_list_prepend (list, na);
            }
        }
    }

    freeifaddrs (ifap);

    return list;
}

void
net_adapter_free (struct net_adapter *na)
{
    g_free (na->name);
    g_free (na->address);
    g_free (na);
}
