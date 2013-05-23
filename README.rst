Changelog
=========

This changelog usually ships with 3 sections, a **Migration Instructions**,
which are the mandatory steps the users have to do to update to a new version,
**Deprecated** which contains deprecated functions which is recommended not to
use but will not break any old code and the **New Features** which are optional
new features available in the new version that users might find interesting.
Even when using them is optional, usually is encouraged.

These instructions should help developers to migrate from one version to
another. The changes listed here are the steps you need to take to move from
the previous version to the one being listed. For example, all the steps
described in version **v1.5** are the steps required to move from **v1.4** to
**v1.5**.

If you need to jump several versions at once, you should read all the steps
from all the involved versions. For example, to jump from **v1.2** to **v1.5**,
you need to first follow the steps in version **v1.3**, then the steps in
version **v1.4** and finally the steps in version **v1.5**.

master
------

Migration Instructions
^^^^^^^^^^^^^^^^^^^^^^

``ocean.crypt.HMAC``
  The ``init()``, ``digest()`` and ``hexDigest()`` methods now take a
  ``ref ubyte[]`` buffer, whose length is set as required to avoid a memory
  allocation in the ``binaryDigest()`` method in
  ``tango.util.digest.MerkleDamgard``. Previously the provided buffer would not
  be used (and a new buffer allocated) if it was too short -- and the required
  length was not noted anywhere!

  Note that as the only change to the interface of the class is the addition of
  ``ref`` to the buffer arguments, this change will not cause compilation
  errors in application code. Therefore you need to really check where your code
  is using this module. (Simply passing a persistent buffer to the methods is
  enough -- there's no need to set its length beforehand.)

New Features
^^^^^^^^^^^^

``ocean.net.client.curl.process.CurlProcessMulti``
  Timeouts for slow downloads can now be specified with ``speedTimeout()``.

v1.2 (2013-05-15)
-----------------

New Features
^^^^^^^^^^^^

``ocean.io.serialize.StructLoader``
  The new ``StructLoader.loadExtend()`` method simplifies deserialization of
  data of a struct with branched arrays. It automatically sets the length of the
  given input buffer as required to store the branched array instances.
  Note that the benefit of ``StructLoader.loadExtend()`` over
  ``StructLoader.load()`` is only significant for structs with branched arrays.

``ocean.net.client.curl.process.CurlProcessMulti``
  The user agent string can now be specified with
  ``userAgent()``.

Migration Instructions
^^^^^^^^^^^^^^^^^^^^^^

``ocean.core.Exception``
  The Exception classes which were previously declared in this module have been
  moved into the modules of the associated classes. For example
  ``ArrayMapException`` now lives in ``ocean.core.ArrayMap``.

``ocean.net.client.curl.CurlProcessMulti``
  The ``max_redirects()`` method is renamed as ``maxRedirects``

``ocean.text.util.StringC``
  The ``StringC.toCstring()`` methods take their string parameter now  as a 
  ``ref char[]`` instead of just ``char[]``. The methods might modify the string
  by appending a null terminating character to its end.

v1.1 (2013-04-09)
-----------------

Migration Instructions
^^^^^^^^^^^^^^^^^^^^^^

``ocean.io.serialize.StructDumper``
  This class is no longer a template, the ``opCall()`` and ``dump()`` methods
  are templates instead. This way you can reuse a single instance of this
  class to dump all kinds of different objects.

  To upgrade you have to remove the template parameter when instantiating the
  class (or referencing the type). Normally the call site for the now templated
  methods don't need to be updated if the template parameter can be correctly
  inferred.

  Note that the new ``BufferedStructDumper`` is the direct equivalent of the old
  ``StructDumper``. The new ``StructDumper`` is a simplified version without an
  internal buffer.

``ocean.net.client.curl.CurlProcessMulti``
  The ``header_only()`` method is replaced by ``header(bool include_body)``. If
  the include_body is set, the header and the message body will be downloaded,
  otherwise only the header.

``ocean.util.config.ConfigParser``
  The ``#`` character will from now on be interpreted as a comment. In debug
  mode a warning will be outputted (though I assume this will be removed in later
  versions)

  To upgrade make sure that you are not using that character in a multiline
  variable. You might did exactly that accidently already, so some configuration
  values that were previously wrong might work now and can cause a changed
  behavior.

Deprecated
^^^^^^^^^^

``ocean.net.client.curl.CurlProcessMulti``
  The names of two methods in the structs returned by the request methods of
  ``CurlProcessMulti`` have changed, as follows:

  ==================== ===================
  Old name             New name
  ==================== ===================
  ``ssl_insecure``     ``sslInsecure``
  ``follow_redirects`` ``followRedirects``
  ==================== ===================

New Features
^^^^^^^^^^^^

``ocean.net.client.curl.process.CurlProcessMulti``
  The maximum number of redirections to follow can now be specified with
  ``max_redirects()``.

``ocean.core.MessageFiber``
  A new debug switch 'MessageFiberDump' was added. It enables a function called 'dumpFibers' which
  can be called from gdb using 'call dumpFibers()'. The performance impact should be relatively low.
  It will output a list on STDERR listing all fibers and some informations about their state.

  Example output::

    Superman: State: HOLD; Token:  DrizzleData; LastSuspend: 1364929515 (3s ago); Addr: 7ff6cad40800; Suspender: ocean.db.drizzle.Connection.Connection
      Tomsen: State: TERM; Token: GroupRequest; LastSuspend: 1364929361 (157s ago); Addr: 7ff6c9ec8f00; Suspender: core.input.TrackingLoglineSource.FiberGroupRetry!(GetRange).FiberGroupRetry
      Marine: State: TERM; Token:     io_ready; LastSuspend: 1364929357 (161s ago); Addr: 7ff6c9eef100; Suspender: swarm.core.protocol.FiberSelectReader.FiberSelectReader
      Robert: State: TERM; Token:     io_ready; LastSuspend: 1364929357 (161s ago); Addr: 7ff6c9f94a00; Suspender: swarm.core.protocol.FiberSelectReader.FiberSelectReader
      Batman: State: HOLD; Token:     io_ready; LastSuspend: 1364929357 (161s ago); Addr: 7ff6c9f94300; Suspender: swarm.core.protocol.FiberSelectReader.FiberSelectReader
       David: State: TERM; Token:  event_fired; LastSuspend: 1364929357 (161s ago); Addr: 7ff6c9fc7c00; Suspender: ocean.io.select.event.FiberSelectEvent.FiberSelectEvent
       Gavin: State: HOLD; Token:     io_ready; LastSuspend: 1364929357 (161s ago); Addr: 7ff6c9fc7500; Suspender: swarm.core.protocol.FiberSelectReader.FiberSelectReader
       Gavin: State: HOLD; Token:  DrizzleData; LastSuspend: 1364929515 (3s ago); Addr: 7ff6cad40600; Suspender: ocean.db.drizzle.Connection.Connection


v1.0 (2013-03-12)
-----------------

* First stable branch
