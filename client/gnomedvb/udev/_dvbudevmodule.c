#ifdef HAVE_CONFIG_H
#include <config.h>
#endif

#include <Python.h>

#define G_UDEV_API_IS_SUBJECT_TO_CHANGE 1
#include <gudev/gudev.h>

static PyObject * dvbudev_get_dvb_devices (PyObject *self, PyObject *args);

static PyMethodDef py_dvbudevmodule_functions[] = {
  {"get_dvb_devices", dvbudev_get_dvb_devices, METH_VARARGS,
    "Retrieve a list of all connected DVB devices."},
  {NULL, NULL, 0, NULL}        /* Sentinel */
};

static const gchar* const subsystems[] = { "dvb", NULL };

PyMODINIT_FUNC
init_dvbudev (void)
{
  PyObject *m, *depends_module;

  m = Py_InitModule ("_dvbudev", py_dvbudevmodule_functions);

  depends_module = PyImport_ImportModule ("gobject");
  Py_DECREF (depends_module);
}

static PyObject *
dvbudev_get_dvb_devices (PyObject *self, PyObject *args)
{
  GUdevClient *client;
  GList *devices, *l;
  GUdevDevice *dev, *parent;
  PyObject *devices_list, *device_infos, *obj;
  const gchar *device_file;

  client = g_udev_client_new (subsystems);

  devices = g_udev_client_query_by_subsystem (client, "dvb");

  devices_list = PyList_New (0);
  for (l = devices; l; l = l->next)
  {
    dev = (GUdevDevice*)l->data;

    device_file = g_udev_device_get_device_file (dev);

    if (g_strstr_len (device_file, -1, "frontend") != NULL)
    {
      device_infos = PyDict_New ();

      obj = PyString_FromString (device_file);
      PyDict_SetItemString (device_infos, "device_file", obj);
      Py_DECREF (obj);

      parent = g_udev_device_get_parent (dev);

      obj = PyString_FromString (g_udev_device_get_sysfs_attr (parent,
        "manufacturer"));
      PyDict_SetItemString (device_infos, "manufacturer", obj);
      Py_DECREF (obj);
      
      obj = PyString_FromString (g_udev_device_get_sysfs_attr (
        parent, "product"));
      PyDict_SetItemString (device_infos, "product", obj);
      Py_DECREF (obj);

      PyList_Append (devices_list, device_infos);
      Py_DECREF (device_infos);
      
      g_object_unref (G_OBJECT (parent));
    }
      
    g_object_unref (G_OBJECT (dev));
  }
 
  g_list_free (devices);
  g_object_unref (G_OBJECT (client));

  return devices_list;
}

