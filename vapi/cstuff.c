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
