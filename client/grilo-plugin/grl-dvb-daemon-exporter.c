/* -*- Mode: C; indent-tabs-mode: t; c-basic-offset: 4; tab-width: 4 -*-  */
/*
 * grl-dvb-daemon-exporter.c
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

#include "gdd-device-group.h"

#include "grl-dvb-daemon-exporter.h"

static GrlMedia * create_media_container (GrlDvbDaemonExporter *self);

struct _GrlDvbDaemonExporterPrivate
{
	GDBusConnection *bus;
	gchar *object_path;
	gchar *name;
	gchar *channel_list_path;
};


enum
{
	PROP_0,

	PROP_OBJECT_PATH,
	PROP_NAME
};



G_DEFINE_TYPE (GrlDvbDaemonExporter, grl_dvb_daemon_exporter, G_TYPE_OBJECT);

static void
grl_dvb_daemon_exporter_init (GrlDvbDaemonExporter *grl_dvb_daemon_exporter)
{
	grl_dvb_daemon_exporter->priv = G_TYPE_INSTANCE_GET_PRIVATE (grl_dvb_daemon_exporter, GRL_TYPE_DVB_DAEMON_EXPORTER, GrlDvbDaemonExporterPrivate);

	/* TODO: Add initialization code here */
	grl_dvb_daemon_exporter->priv->bus = NULL;
	grl_dvb_daemon_exporter->priv->name = NULL;
	grl_dvb_daemon_exporter->priv->channel_list_path = NULL;
}

static void
grl_dvb_daemon_exporter_finalize (GObject *object)
{
	/* TODO: Add deinitalization code here */
	GrlDvbDaemonExporterPrivate *priv = GRL_DVB_DAEMON_EXPORTER (object)->priv;

	if (priv->bus != NULL)
		g_object_unref (priv->bus);
	if (priv->object_path != NULL)
		g_free (priv->object_path);
	if (priv->name != NULL)
		g_free (priv->name);
	if (priv->channel_list_path != NULL)
		g_free (priv->channel_list_path);

	G_OBJECT_CLASS (grl_dvb_daemon_exporter_parent_class)->finalize (object);
}

static void
grl_dvb_daemon_exporter_set_property (GObject *object, guint prop_id, const GValue *value, GParamSpec *pspec)
{
	g_return_if_fail (GRL_IS_DVB_DAEMON_EXPORTER (object));

	GrlDvbDaemonExporter *self = GRL_DVB_DAEMON_EXPORTER (object);

	switch (prop_id)
	{
	case PROP_OBJECT_PATH:
		if (self->priv->object_path != NULL)
			g_free (self->priv->object_path);
		self->priv->object_path = g_value_dup_string (value);
		break;
	default:
		G_OBJECT_WARN_INVALID_PROPERTY_ID (object, prop_id, pspec);
		break;
	}
}

static void
grl_dvb_daemon_exporter_get_property (GObject *object, guint prop_id, GValue *value, GParamSpec *pspec)
{
	g_return_if_fail (GRL_IS_DVB_DAEMON_EXPORTER (object));

	GrlDvbDaemonExporter *self = GRL_DVB_DAEMON_EXPORTER (object);

	switch (prop_id)
	{
	case PROP_OBJECT_PATH:
		g_value_set_string (value, self->priv->object_path);
		break;
	case PROP_NAME:
		g_value_set_string (value, self->priv->name);
		break;
	default:
		G_OBJECT_WARN_INVALID_PROPERTY_ID (object, prop_id, pspec);
		break;
	}
}

static void
grl_dvb_daemon_exporter_class_init (GrlDvbDaemonExporterClass *klass)
{
	GObjectClass* object_class = G_OBJECT_CLASS (klass);

	g_type_class_add_private (klass, sizeof (GrlDvbDaemonExporterPrivate));

	object_class->finalize = grl_dvb_daemon_exporter_finalize;
	object_class->set_property = grl_dvb_daemon_exporter_set_property;
	object_class->get_property = grl_dvb_daemon_exporter_get_property;

	g_object_class_install_property (object_class,
	                                 PROP_OBJECT_PATH,
	                                 g_param_spec_string ("object-path",
	                                                      "object path",
	                                                      "DBus object path to device group",
	                                                      NULL,
	                                                      G_PARAM_READABLE | G_PARAM_WRITABLE | G_PARAM_CONSTRUCT_ONLY));

	g_object_class_install_property (object_class,
	                                 PROP_NAME,
	                                 g_param_spec_string ("name",
	                                                      "Name",
	                                                      "Name of device group",
	                                                      NULL,
	                                                      G_PARAM_READABLE));
}

static GrlMedia *
create_media_container (GrlDvbDaemonExporter *self)
{
	GrlMedia * container = GRL_MEDIA (grl_media_container_new ());
	grl_media_set_id (container, self->priv->channel_list_path);
	grl_media_set_title (container, self->priv->name);
	return container;
}

GrlMedia *
grl_dvb_daemon_exporter_get_media_container (GrlDvbDaemonExporter *self,
                                         GCancellable *cancellable,
                                         GError **error)
{
	GddDeviceGroup *proxy = NULL;
	if (self->priv->name == NULL) {
		proxy = gdd_device_group__proxy_new_sync (self->priv->bus,
			                         G_DBUS_PROXY_FLAGS_NONE,
			                         "org.gnome.DVB",
			                         self->priv->object_path,
			                         cancellable, error);
		if (proxy == NULL)
			goto on_error;

		if (!gdd_device_group__call_get_name_sync (proxy, &self->priv->name,
			                                       cancellable, error))
		{
			goto on_error;
		}

		if (!gdd_device_group__call_get_channel_list_sync (proxy,
			                                               &self->priv->channel_list_path,
			                                               cancellable,
			                                               error))
		{
			goto on_error;
		}

		g_object_unref (proxy);
	}

	return create_media_container (self);

on_error:
	if (proxy != NULL)
		g_object_unref (proxy);

	return NULL;
}

GrlDvbDaemonExporter*
grl_dvb_daemon_exporter_new (const gchar *path, GDBusConnection *bus)
{
	g_return_val_if_fail (path != NULL, NULL);

	GrlDvbDaemonExporter *self = g_object_new (GRL_TYPE_DVB_DAEMON_EXPORTER,
	                                             "object-path", path, NULL);
	self->priv->bus = g_object_ref (bus);
	return self;
}
