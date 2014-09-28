/* -*- Mode: C; indent-tabs-mode: t; c-basic-offset: 4; tab-width: 4 -*-  */
/*
 * grl-dvb-daemon-source.c
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

#ifdef HAVE_CONFIG_H
#include "config.h"
#endif

#include "gdd-manager.h"
#include "gdd-channel-list.h"
#include "grl-dvb-daemon-exporter.h"

#include "grl-dvb-daemon-source.h"

/* --- Plugin information --- */

#define PLUGIN_ID   DVBDAEMON_PLUGIN_ID

#define SOURCE_ID   "grl-dvb-daemon"
#define SOURCE_NAME "DVB Daemon"
#define SOURCE_DESC "A source to access TV and radio channels"

/* --------- Logging  -------- */

#define GRL_LOG_DOMAIN_DEFAULT dvbdaemon_log_domain
GRL_LOG_DOMAIN_STATIC(dvbdaemon_log_domain);


static const GList * grl_dvb_daemon_source_supported_keys (GrlSource *source);

static void grl_dvb_daemon_source_browse (GrlSource *source,
                                          GrlSourceBrowseSpec *bs);

static gboolean grl_dvb_daemon_source_connect_bus (GrlDvbDaemonSource *source);

static GrlMedia * create_channel_media (GVariant * value);

/* --------- Callbacks  -------- */

static void on_manager_proxy_cb (GObject *source,
                                 GAsyncResult *res,
                                 gpointer user_data);

static void on_manager_get_device_groups_cb (GObject *source,
                                             GAsyncResult *res,
                                             gpointer user_data);

static void on_channel_list_proxy_cb (GObject *source,
                                      GAsyncResult *res,
                                      gpointer user_data);

struct _GrlDvbDaemonSourcePrivate
{
	GDBusConnection* bus;
};


G_DEFINE_TYPE (GrlDvbDaemonSource, grl_dvb_daemon_source, GRL_TYPE_SOURCE);


/* ================== DVB Daemon Plugin ================ */

static gboolean
grl_dvb_daemon_plugin_init (GrlRegistry *registry,
                     GrlPlugin *plugin,
                     GList *configs)
{
	GRL_LOG_DOMAIN_INIT (dvbdaemon_log_domain, "dvbdaemon");

	GRL_DEBUG ("grl_dvb_daemon_plugin_init");

	GrlDvbDaemonSource *source = grl_dvb_daemon_source_new ();
	if (grl_dvb_daemon_source_connect_bus (source)) {
		grl_registry_register_source (registry,
		                              plugin,
		                              GRL_SOURCE (source),
		                              NULL);
		return TRUE;
	}
	return FALSE;
}

GRL_PLUGIN_REGISTER (grl_dvb_daemon_plugin_init, NULL, DVBDAEMON_PLUGIN_ID);


/* ================== DVB Daemon GObject ================ */

static void
grl_dvb_daemon_source_init (GrlDvbDaemonSource *grl_dvb_daemon_source)
{
	grl_dvb_daemon_source->priv = G_TYPE_INSTANCE_GET_PRIVATE (grl_dvb_daemon_source, GRL_TYPE_DVB_DAEMON_SOURCE, GrlDvbDaemonSourcePrivate);

	/* TODO: Add initialization code here */
}

static void
grl_dvb_daemon_source_finalize (GObject *object)
{
	GrlDvbDaemonSourcePrivate* priv = GRL_DVB_DAEMON_SOURCE (object)->priv;

	/* TODO: Add deinitalization code here */
	if (priv->bus != NULL) {
		g_dbus_connection_close_sync (priv->bus, NULL, NULL);
		g_object_unref (priv->bus);
	}

	G_OBJECT_CLASS (grl_dvb_daemon_source_parent_class)->finalize (object);
}

static void
grl_dvb_daemon_source_class_init (GrlDvbDaemonSourceClass *klass)
{
	GObjectClass* object_class = G_OBJECT_CLASS (klass);
	GrlSourceClass *source_class = GRL_SOURCE_CLASS (klass);

	object_class->finalize = grl_dvb_daemon_source_finalize;

	source_class->supported_keys = grl_dvb_daemon_source_supported_keys;
	source_class->browse = grl_dvb_daemon_source_browse;

	g_type_class_add_private (klass, sizeof (GrlDvbDaemonSourcePrivate));
}

GrlDvbDaemonSource*
grl_dvb_daemon_source_new (void)
{
	return g_object_new (GRL_TYPE_DVB_DAEMON_SOURCE,
                        "source-id", SOURCE_ID,
                        "source-name", SOURCE_NAME,
                        "source-desc", SOURCE_DESC,
                        NULL);
}

static gboolean
grl_dvb_daemon_source_connect_bus (GrlDvbDaemonSource *source)
{
	GError *error = NULL;

	source->priv->bus = g_bus_get_sync (G_BUS_TYPE_SESSION, NULL, &error);
	if (source->priv->bus == NULL) {
		GRL_ERROR ("Error connecting to session bus: %s", error->message);
		g_error_free (error);
		return FALSE;
	}
	return TRUE;
}

static const GList *
grl_dvb_daemon_source_supported_keys (GrlSource *source)
{
	static GList *keys = NULL;
	if (!keys) {
		keys = grl_metadata_key_list_new (GRL_METADATA_KEY_ID,
                                      GRL_METADATA_KEY_TITLE,
                                      GRL_METADATA_KEY_URL,
                                      GRL_METADATA_KEY_CHILDCOUNT,
                                      NULL);
	}
	return keys;
}

static void
grl_dvb_daemon_source_browse (GrlSource *source,
                              GrlSourceBrowseSpec *bs)
{
	GrlDvbDaemonSource *self = GRL_DVB_DAEMON_SOURCE(source);
	GRL_DEBUG ("grl_dvb_daemon_source_browse");

    const gchar* channel_list_path = grl_media_get_id (bs->container);
	if (channel_list_path == NULL) {
		gdd_manager__proxy_new (self->priv->bus,
		                        G_DBUS_PROXY_FLAGS_NONE,
		                        "org.gnome.DVB",
		                        "/org/gnome/DVB/Manager",
		                        NULL,
		                        on_manager_proxy_cb, bs);
	} else {
		GRL_DEBUG ("Browsing device group with ID %s", channel_list_path);

		gdd_channel_list__proxy_new (self->priv->bus,
	                             G_DBUS_PROXY_FLAGS_NONE,
	                             "org.gnome.DVB",
	                             channel_list_path,
	                             NULL,
	                             on_channel_list_proxy_cb, bs);
	}
}

static void
on_manager_proxy_cb (GObject *source, GAsyncResult *res, gpointer user_data)
{
	GddManager *manager;
	GError *error = NULL;
	GrlSourceBrowseSpec *bs = user_data;

	manager = gdd_manager__proxy_new_finish (res, &error);
	if (manager == NULL) {
		GRL_ERROR ("Failed creating Manager proxy: %s", error->message);
		goto on_error;
	}

	gdd_manager__call_get_registered_device_groups (manager, NULL,
	                                                on_manager_get_device_groups_cb,
	                                                user_data);
	return;

on_error:
	bs->callback (bs->source, bs->operation_id, NULL, 0, bs->user_data, error);
	g_error_free (error);
	return;
}

static void
on_manager_get_device_groups_cb (GObject *source, GAsyncResult *res,
                                 gpointer user_data)
{
	gchar **object_paths;
	gint n_groups;
	GError *error = NULL;
	GddManager *manager = GDD_MANAGER_ (source);
	GrlSourceBrowseSpec *bs = user_data;

	if (!gdd_manager__call_get_registered_device_groups_finish (manager,
	                                                            &object_paths,
	                                                            res,
	                                                            &error))
	{
		GRL_ERROR ("Error retrieving device groups: %s", error->message);
		goto on_error;
	}

	if (!gdd_manager__call_get_device_group_size_sync (manager, &n_groups,
	                                                   NULL, &error))
	{
		GRL_ERROR ("Error retrieving number of device groups: %s", error->message);
		goto on_error;
	}

	GRL_DEBUG ("Retrieving %d device groups", n_groups);

	while (*object_paths != NULL) {
		GrlDvbDaemonExporter *exporter;
		GrlMedia *box;
		GRL_DEBUG ("Adding media box with ID %s", *object_paths);

		exporter = grl_dvb_daemon_exporter_new (*object_paths,
		                                          GRL_DVB_DAEMON_SOURCE(bs->source)->priv->bus);
		box = grl_dvb_daemon_exporter_get_media_box (exporter, NULL, &error);
		if (box == NULL) {
			g_object_unref (exporter);
			goto on_error;
		}

		bs->callback (bs->source, bs->operation_id, box,
		              --n_groups, bs->user_data, NULL);

		g_object_unref (exporter);
		object_paths++;
	}
	return;

on_error:
	bs->callback (bs->source, bs->operation_id, NULL, 0, bs->user_data, error);
	g_error_free (error);
	return;
}

static GrlMedia *
create_channel_media (GVariant * value)
{
	GVariant *var_sid, *var_name, *var_radio, *var_url;
	gchar *sid_str;
	GrlMedia *channel;

	var_sid = g_variant_get_child_value (value, 0);
	var_name = g_variant_get_child_value (value, 1);
	var_radio = g_variant_get_child_value (value, 2);
	var_url = g_variant_get_child_value (value, 3);

	if (g_variant_get_boolean (var_radio))
		channel = GRL_MEDIA (grl_media_audio_new ());
	else
		channel = GRL_MEDIA (grl_media_video_new ());

	sid_str = g_strdup_printf ("%u", g_variant_get_uint32 (var_sid));
	GRL_DEBUG ("Creating channel media %s", sid_str);

	grl_media_set_id (channel, sid_str);
	grl_media_set_title (channel, g_variant_get_string (var_name, NULL));
	grl_media_set_url (channel, g_variant_get_string (var_url, NULL));

	g_free (sid_str);
	g_variant_unref (var_sid);
	g_variant_unref (var_name);
	g_variant_unref (var_radio);
	g_variant_unref (var_url);

	return channel;
}

static void
on_channel_list_proxy_cb (GObject *source, GAsyncResult *res, gpointer user_data)
{
	GError *error = NULL;
	GddChannelList *list;
	GVariant *channels = NULL;
	GVariant *child = NULL;
	GVariantIter iter;
	gsize n_channels;
	GrlSourceBrowseSpec *bs = user_data;

	list = gdd_channel_list__proxy_new_finish (res, &error);
	if (list == NULL) {
		goto on_error;
	}

	if (!gdd_channel_list__call_get_channel_infos_sync (list, &channels,
	                                                    NULL, &error))
	{
		goto on_error;
	}

	n_channels = g_variant_n_children (channels);
	g_variant_iter_init (&iter, channels);
	while ((child = g_variant_iter_next_value (&iter))) {
		GrlMedia *channel = create_channel_media (child);

		bs->callback (bs->source, bs->operation_id, channel,
		              --n_channels, bs->user_data, NULL);

		g_variant_unref (child);
	}

	g_variant_unref (channels);
	g_object_unref (list);
	return;

on_error:
	if (child != NULL)
		g_variant_unref (child);
	if (channels != NULL)
		g_variant_unref (channels);
	if (list != NULL)
		g_object_unref (list);
	bs->callback (bs->source, bs->operation_id, NULL, 0, bs->user_data, error);
	g_error_free (error);
}
