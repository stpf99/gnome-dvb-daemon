/* -*- Mode: C; indent-tabs-mode: t; c-basic-offset: 4; tab-width: 4 -*-  */
/*
 * grl-dvb-daemon-exporter.h
 * Copyright (C) 2014 Sebastian Pölsterl
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

#ifndef _GRL_DVB_DAEMON_EXPORTER_H_
#define _GRL_DVB_DAEMON_EXPORTER_H_

#include <glib-object.h>
#include <gio/gio.h>
#include <grilo.h>

G_BEGIN_DECLS

#define GRL_TYPE_DVB_DAEMON_EXPORTER             (grl_dvb_daemon_exporter_get_type ())
#define GRL_DVB_DAEMON_EXPORTER(obj)             (G_TYPE_CHECK_INSTANCE_CAST ((obj), GRL_TYPE_DVB_DAEMON_EXPORTER, GrlDvbDaemonExporter))
#define GRL_DVB_DAEMON_EXPORTER_CLASS(klass)     (G_TYPE_CHECK_CLASS_CAST ((klass), GRL_TYPE_DVB_DAEMON_EXPORTER, GrlDvbDaemonExporterClass))
#define GRL_IS_DVB_DAEMON_EXPORTER(obj)          (G_TYPE_CHECK_INSTANCE_TYPE ((obj), GRL_TYPE_DVB_DAEMON_EXPORTER))
#define GRL_IS_DVB_DAEMON_EXPORTER_CLASS(klass)  (G_TYPE_CHECK_CLASS_TYPE ((klass), GRL_TYPE_DVB_DAEMON_EXPORTER))
#define GRL_DVB_DAEMON_EXPORTER_GET_CLASS(obj)   (G_TYPE_INSTANCE_GET_CLASS ((obj), GRL_TYPE_DVB_DAEMON_EXPORTER, GrlDvbDaemonExporterClass))

typedef struct _GrlDvbDaemonExporterClass GrlDvbDaemonExporterClass;
typedef struct _GrlDvbDaemonExporter GrlDvbDaemonExporter;
typedef struct _GrlDvbDaemonExporterPrivate GrlDvbDaemonExporterPrivate;


struct _GrlDvbDaemonExporterClass
{
	GObjectClass parent_class;
};

struct _GrlDvbDaemonExporter
{
	GObject parent_instance;

	GrlDvbDaemonExporterPrivate *priv;
};

GrlDvbDaemonExporter * grl_dvb_daemon_exporter_new (const gchar *path, GDBusConnection *bus);
GrlMedia * grl_dvb_daemon_exporter_get_media_container (GrlDvbDaemonExporter *self,
                                                    GCancellable *cancellable,
                                                    GError **error);

void grl_dvb_daemon_exporter_run (GrlDvbDaemonExporter *);

GType grl_dvb_daemon_exporter_get_type (void) G_GNUC_CONST;

G_END_DECLS

#endif /* _GRL_DVB_DAEMON_EXPORTER_H_ */

