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

``ocean.util.container.map.FileSerializer``
  Loading files with version < 2 is not longer supported, since the older
  versions was deprecated a long time ago. If you have a file with
  version < 2, use ocean v1.8.1 to load the map and dump it to get it as
  a file of version 2.

``ocean.util.log.Stats``
  The class is no longer is a template class. Instead the according methods
  became template methods

New Features
^^^^^^^^^^^^
``ocean.util.ReusableException`` ``ocean.net.http.HttpException`` ``ocean.core.ErrnoIOException``
  Message argument for `assertEx` calls has been made `lazy` and thus can be
  used with no performance concerns about complex formatting happening in
  normal code flow.

``ocean.util.container.map``
  Every BucketSet based class now features an interruptible iterator, allowing a
  `foreach` to be interrupted (by `break`) and continued where it left off. It is
  provided as a nested class that can be newed using 
  `auto it = map_instance.new InterruptableIterator;` 
  It can be reset to the beginning using `reset()` and queried for its iteration
  status using `finished()`

``ocean.util.app.VersionedLoggedStatsCliApp``
  This class now provides a StatsLog instance, configured from the [STATS]
  section in your configuration file. You can configure `file_name`,
  `max_file_size` and `file_count` in that section.
  The StatsLog instance can be passed to a PeriodicStatsLog instance to have the
  usual 30 seconds logging as you all are used to.

v1.8.1 (2013-10-21)
-------------------

This is an emergency release only to revert a new feature that was buggy and
caused more problems than it solved. If you generate any `map.FileSerializer` files please bare in mind they won't be loaded by future versions, so pleas upgrade to this version as soon as possible!

Migration Instructions
^^^^^^^^^^^^^^^^^^^^^^

``ocean.util.container.map.FileSerializer``
  Files are no longer compressed and it can't read old compressed maps.
  The reason compression is removed is since it didn't work for all maps
  and it took longer time to load a compressed map compared to a
  uncompressed map.

v1.8 (2013-10-16)
-----------------

Migration Instructions
^^^^^^^^^^^^^^^^^^^^^^

``ocean.text.convert.Integer``
  The detection of overflows when attempting to convert strings containing
  numbers which are too large for the destination integer type has been
  improved. It was previously buggy, and could output a junk value rather than
  returning false to indicate a failed conversion.

  The interface of these functions remains the same, but users should be aware
  of this change in behaviour.

``ocean.text.regex.PCRE``
  The meaning of the optional 'case sensitivity' match parameter has been
  reversed. It was previously 'case insensitive', now means 'case sensitive'.
  The new meaning is more intuitive, leading to less confusing double negatives.

New Features
^^^^^^^^^^^^

``ocean.util.container.map.FileSerializer``
  Files are now written compressed (with the Zlib algorithm). Can still read old
  uncompressed maps.

``ocean.util.ClassFiller``
  A new config property struct wrapper was added that makes sure that the config
  value is within a certain set of values:
  ``LimitCmp``, ``LimitInit``, ``Limit``

``ocean.io.Terminal``
  New arrays containing foreground and background colour control codes.
  These arrays are indexed and accessed by an enum of colours, for clarity,
  and to avoid having to pass char[] directly to methods using these codes.

``ocean.io.console.Tables``
  New methods for creating binary and decimal metric cells.
  These methods allow for creation of cells containing a number and a unit,
  both decimal metric (" 5.2 kB ") and binary metric (" 5.2 MiB ").

  New methods for changing the foreground and background colors of a cell.
  They use the ocean.io.Terminal.Colour enum as described above.

  Cell setter methods now return this, to allow chaining calls to them.

``ocean.math.Distribution``
  New method for calculating the mean (average) of the contained values.

  New method for calculating the median of the contained values.

``ocean.text.convert.Hash``
  New module containing functions for converting between various types of hash:
  hash_t, char[] containing hex digits (with our without "0x" at the start),
  char[] containing exactly hash_t.sizeof * 2 hex digits (with our without "0x"
  at the start).

``ocean.text.convert.DateTime``
  New module added that provides methods to convert dates in strings to a
  time_t UNIX timestamp value.

``ocean.text.regex.PCRE``
  * Added a class (CompiledRegex) which can be used to compile a regex pattern
    once and use it to perform multiple searches. (Previously the pattern was
    compiled every time a search was performed.)
  * Added a field which can set the maximum complexity limit of a regex search.
    If the limit is exceeded, the search is aborted. This can be useful to
    control the amount of time spent performing a search.
  * Added a method study() which can be used to increase the processing
    efficiency of a compiled regex.

v1.7 (2013-09-06)
-----------------

Migration Instructions
^^^^^^^^^^^^^^^^^^^^^^

``ocean.util.container.map`` and subpackages
  The default bucket element allocation and disposal method is now using
  ``new``/``delete``.
  Previously the unused buckets were stored in a linked list by default. This
  caused severe slowdown of the GC when scanning for unused references. The new
  method proved to eliminate the performance impact while not causing a memory
  leak condition.
  The linked list pool is still available in
  ``ocean.util.container.map.model.BucketElementFreeList``, and it is useful if
  the bucket elements are preallocated and a reference to each bucket element is
  stored somewhere else. The ``Cache`` is using it in that way.

New Features
^^^^^^^^^^^^

``common.mk``
  The utility common makefile gain a new function: ``check_deb``. This function
  makes very easy to check for debian package dependencies in the build
  process. Please refer to the documentations comment for details on how to use
  it.


v1.6 (2013-08-06)
-----------------

Migration Instructions
^^^^^^^^^^^^^^^^^^^^^^

``ocean.util.container.map.Map``
  ``Map.remove()`` no longer returns a pointer to the removed value. Instead it
  returns a boolean flag and optionally accepts a delegate which is called with
  a reference to the value that is about to be removed. This is because with a
  bucket element deallocation method such as delete the value isn't accessible
  any more after ``remove()`` returned.

``ocean.util.container.map`` and subpackages
  ``BucketSet.newElement()``, inherited by ``Map``, ``Set`` and their subclasses
  has been moved to ``BucketSet.FreeBuckets.newElement()``. Classes which
  override this method need to be adapted to add a ``BucketSet.FreeBuckets``
  subclass that overrides this method and pass an instance of this class to the
  ``Map``/``Set``/``BucketSet`` constructor.

``ocean.net.http``
  This unused package has been removed from ocean.

``ocean.net.http2`` renamed to ``ocean.net.http``
  All code that imports from ``ocean.net.http2`` will need to import from
  ``ocean.net.http``.

``ocean.net.client``
  This whole package has been moved into dive:

  * ``ocean.net.client.curl`` is now in ``dive.net.curl``
  * ``ocean.net.client.sphinx`` is now in ``dive.db.sphinx``
  * ``ocean.net.client.xmlrpc`` is now in ``dive.net.xmlrpc``

``ocean.db.drizzle``
  This whole package has been moved into ``dive.db.drizzle``.

``ocean.text.ling``
  This whole package has been moved into ``dive.text.ling``.

``ocean.util.log.Stats``
  * ``PeriodicStatsLog`` constructor now expects a second delegate, which is
    called after each stats log line is written. The delegate is optional (can
    be null). It can be used, for example, to reset transient values in the
    struct being logged.
  * ``PeriodicStatsLog`` value delegate must now return a pointer to the struct
    to be logged. This avoids making an unnecessary copy of the struct.

New Features
^^^^^^^^^^^^

``ocean.util.container.map`` and subpackages
  ``BucketSet`` and subclasses allow using a custom allocator or pool for the
  bucket elements. Such a custom pool and allocator implementation needs to
  implement the ``IAllocator`` interface in
  ``ocean.core.util.map.model.IAllocator`` and an instance of it can be passed
  to the ``Map``/``Set``/``BucketSet`` constructor. It is also possible to use
  the built-in pool implementation and only customise the allocation method by
  deriving from ``BucketSet.FreeBuckets`` and overriding ``newElement()``.

``ocean.io.console.AppStatus``
  The protected printExtraVersionInformation() can be overridden by derived
  classes in order to display additional information in the app status display,
  after the standard version info line has been printed.

``ocean.sys.socket.model.IAddressIPSocketInfo``
  The new informational (non-destructive) interface ``IAddressIPSocketInfo``,
  which is implemented by ``AddressIPSocket``, allows user code to pass around
  safe instances of ``AddressIPSocket`` to places which shouldn't have access to
  its "mutator" methods.

``ocean.io.select.model.IConnectionHandlerInfo``
  The new informational (non-destructive) interface ``IConnectionHandlerInfo``,
  which is implemented by ``IConnectionHandler``, allows user code to pass
  around safe instances of ``IConnectionHandler`` to places which shouldn't have
  access to its "mutator" methods. Specifically, a method which returns an
  informational interface to the connection handler's socket
  (``IAddressIPSocketInfo``) is added.

``ocean.io.select.model.ISelectClientInfo``
  The new informational (non-destructive) interface ``ISelectClientInfo``,
  which is implemented by ``ISelectClient``, allows user code to pass around
  safe instances of ``SelectClient`` to places which shouldn't have access to
  its "mutator" methods.

``ocean.io.select.model.ISelectListenerPoolInfo``
  The new informational (non-destructive) interface ``ISelectListenerPoolInfo``,
  which is implemented by ``SelectListenerPool`` (the pool of connections
  handled by a ``SelectListener``), adds foreach iterators over informational
  interfaces (``IConnectionHandlerInfo``) to the connections in the pool.

``ocean.io.select.SelectListener``
  The ``poolInfo()`` method now returns an ``ISelectListenerPoolInfo``
  interface, allowing iteration over the pool of active connections.

``ocean.io.select.fiber.SelectFiber``
  Now contains a method ``registered_client()`` which returns an informational
  interface (``ISelectClientInfo``) to the select client which is currently
  registered for the fiber.

``common.mk``
  The utility common makefile gained a couple of new functions:
  ``path_to_module`` and ``invoke_xfbuild``. The former converts from
  ``package/module.d`` to ``package.module`` and the later is a wrapper to call
  ``xfbuild`` to make a full build and making other assumptions. See the
  documentation comments for details.


v1.5 (2013-07-04)
-----------------

New Features
^^^^^^^^^^^^
``ocean.text.json.JsonExtractor``
  Add a ``strict`` flag to JsonExtractor which is a public field that can be
  changed at any time. When JSON Object has just been parsed and ``strict`` is
  set to ``true``, JsonExtractor verifies that all defined fields where found in
  JSON source and throws Exception otherwise.

``ocean.io.FilePath``
  This is a new module extending ``tango.io.FilePath`` to add extended
  functionality. Right now it only adds the ``link()`` method, which creates
  a hard link (see ``link(2)`` manpage for details).


v1.4 (2013-06-18)
-----------------

New Features
^^^^^^^^^^^^

``ocean.db.drizzle.RecordParser``
  Add a try/catch when parsing results from a char array to the relevant field
  of the result struct in the ``setField`` method. If an exception is caught
  set the field of the result struct to the init value of that field. The
  constructor can also optionally take an error notifier which is called when
  an exception is caught. These changes do not require changes to application
  code.

``ocean.io.select.EpollSelectDispatcher``
  ``EpollSelectDispatcher`` now also implements the interface
  ``IEpollSelectDispatcherInfo`` (``ocean.io.select.model.IEpollSelectDispatcherInfo``),
  which contains methods to provide information about the state of the select
  dispatcher. This interface allows the separation of purely informational
  access to the select dispatcher from "destructive" use of it (i.e. methods
  which can actually modify its state). Currently only a single method
  (``num_registered()``) exists in the interface by default, but additional
  methods (``selects()`` and ``timeouts()``) can be added by compiling with
  version = EpollCounters.

v1.3 (2013-05-29)
-----------------

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

``ocean.d.ebtree.model.IEBtree`` and all derived ``EBTree*`` classes
  The ``minimize()`` method has been removed. This is because the pool of ebtree
  nodes now allows implementing a custom allocation method by deriving from the
  ``NodePool`` class and some allocation methods do not support minimizing the
  pool size. An example (and actual the reason why this was changed) is to
  preallocate all nodes in a contiguous buffer if the maximum number of nodes in
  the tree is known in advance; this is now done in the ``Cache``.

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

``ocean.net.http.Url``
  The handling of 2-digit percent-encoding in URLs was completely wrong.
  It now follows the spec for UTF8 percent-encoding.
  Unfortunately the front-end was relying on the wrong behaviour, so ocean
  remains backwards compatible with it.
  See bug 93 for details.

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
