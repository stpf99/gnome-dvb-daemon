/* -*- Mode: C; indent-tabs-mode: t; c-basic-offset: 4; tab-width: 4 -*-  */
/*
 * grl-dvb-daemon-source.h
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

#ifndef _GRL_DVB_DAEMON_SOURCE_H_
#define _GRL_DVB_DAEMON_SOURCE_H_

#include <grilo.h>

G_BEGIN_DECLS

#define GRL_TYPE_DVB_DAEMON_SOURCE             (grl_dvb_daemon_source_get_type ())
#define GRL_DVB_DAEMON_SOURCE(obj)             (G_TYPE_CHECK_INSTANCE_CAST ((obj), GRL_TYPE_DVB_DAEMON_SOURCE, GrlDvbDaemonSource))
#define GRL_DVB_DAEMON_SOURCE_CLASS(klass)     (G_TYPE_CHECK_CLASS_CAST ((klass), GRL_TYPE_DVB_DAEMON_SOURCE, GrlDvbDaemonSourceClass))
#define GRL_IS_DVB_DAEMON_SOURCE(obj)          (G_TYPE_CHECK_INSTANCE_TYPE ((obj), GRL_TYPE_DVB_DAEMON_SOURCE))
#define GRL_IS_DVB_DAEMON_SOURCE_CLASS(klass)  (G_TYPE_CHECK_CLASS_TYPE ((klass), GRL_TYPE_DVB_DAEMON_SOURCE))
#define GRL_DVB_DAEMON_SOURCE_GET_CLASS(obj)   (G_TYPE_INSTANCE_GET_CLASS ((obj), GRL_TYPE_DVB_DAEMON_SOURCE, GrlDvbDaemonSourceClass))

typedef struct _GrlDvbDaemonSourceClass GrlDvbDaemonSourceClass;
typedef struct _GrlDvbDaemonSource GrlDvbDaemonSource;
typedef struct _GrlDvbDaemonSourcePrivate GrlDvbDaemonSourcePrivate;


struct _GrlDvbDaemonSourceClass
{
	GrlSourceClass parent_class;
};

struct _GrlDvbDaemonSource
{
	GrlSource parent_instance;

	GrlDvbDaemonSourcePrivate *priv;
};

GrlDvbDaemonSource* grl_dvb_daemon_source_new (void);
GType grl_dvb_daemon_source_get_type (void) G_GNUC_CONST;

G_END_DECLS

#endif /* _GRL_DVB_DAEMON_SOURCE_H_ */

