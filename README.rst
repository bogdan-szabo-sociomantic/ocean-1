Description
===========

Ocean is a base, platform-dependant general purpose D library with all the
required core functionality that is missing from the language standard library
(Tango).  Part of Ocean is dedicated to fill some gaps in Tango or add some
improvements over the existing modules, but a big part of it contains very
low-level infrastructure need to do real-time applications efficiently, that's
why memory allocation minimization is a key component in Ocean's design. For
the same reason a lot of non-portable constructions are used in Ocean.


Changelog
=========

This changelog usually ships with 3 sections, a **Migration Instructions**,
which are the mandatory steps the users have to do to update to a new version,
**Deprecated** which contains deprecated functions which is recommended not to
use but will not break any old code and the **New Features** which are optional
new features available in the new version that users might find interesting.
Using them is optional, but encouraged.

These instructions should help developers to migrate from one version to
another. The changes listed here are the steps you need to take to move from
the previous version to the one being listed. For example, all the steps
described in version **v1.5** are the steps required to move from **v1.4** to
**v1.5**.

If you need to jump several versions at once, you should read all the steps from
all the intermediate versions. For example, to jump from **v1.2** to **v1.5**,
you need to first follow the steps in version **v1.3**, then the steps in
version **v1.4** and finally the steps in version **v1.5**.

master
------

New Features
^^^^^^^^^^^^

``ocean.core.Exception``
  ``assertEx`` functions replaced with ``enforce`` with similar functionality but
  different API. Requires dmd1 package version "1.076.s2".
  Check https://github.com/sociomantic/ocean/wiki/Standard-error-handling-and-testing for details.

``ocean.core.Test``
  New module that defines standard exception type to be thrown from unit tests
  and provides set of helper functions similar to ``enforce`` that throw exactly
  this exception type. Also has ``NamedTest`` class for better error reporting
  in complicated unit tests.
  Check https://github.com/sociomantic/ocean/wiki/Standard-error-handling-and-testing for details.

``ocean.core.Traits``
  New helper ``toDg`` creates a delegate from function pointer, useful when
  method has signature expecting former and you have latter.

``ocean.io.serialize.StructLoader``
  Versioned structs are now capable of bi-directional conversion, both to
  previous and next versions. Forward conversion only works if struct definition
  has ``StructNext`` member alias and appropriate ``convert_x`` methods for
  non-trivial field conversion. Multiple ``convert_x`` methods can be present
  to support both directions, correct one is chosen based on argument type.

  If received byte buffer has version with no matching ``StructPrevious`` or
  ``StructNext`` aliases for this struct, runtime error will happen.

``ocean.math.Range``
  New module with a struct for basic operations (overlaps, subset, superset,
  subtract, etc) over integer ranges.

``ocean.io.console.Tables``
  The Tables API now has an optional thousands comma separation for columns
  with integer values. Previously comma separation was hardcoded-in, but is
  now toggle-able. The new API preserves backwards compatibility.

Migration Instructions
^^^^^^^^^^^^^^^^^^^^^^

``ocean.util.container.ebtree``, ``ocean.io.compress.lzo``
  These modules don't use a ``pragma(lib, ...)`` anymore, so you need to
  explicitly link using ``-lebtree`` or ``-llzo2`` now. Make sure to update
  your Makefiles.

``ocean.core.Exception``
  Rename ``assertEx`` to ``enforce``. If variadic argument list has been used, format
  it into single message argument at call site (this argument is lazy). You can also
  remove explicit mentions of __FILE__ and __LINE__ (not necessary but recommended).

``ocean.util.Unittest``
  This module is deprecated. Replace ``assertLog`` with ``ocean.core.Test.test``. Where
  necessary, replace ``Unittest`` with ``NamedTest``. NB: ``NamedTest`` is NOT as scope
  class.

``ocean.util.app.UnittestedApp``
``ocean.util.app.ext.UnittestExt``
  These modules are deprecated, simply remove them from your application extensions.

``ocean.core.Cache``
``ocean.util.Main``
  These modules are completely removed being deprecated for many ocean releases now.
  You should have stopped using them long time ago.

v1.14 (2014-06-20)
------------------

Migration Instructions
^^^^^^^^^^^^^^^^^^^^^^

``ocean.util.log.LayoutStatsLog``
  - This layout class has been moved into ``ocean.util.log.layout.*``

``ocean.util.log.MessageOnlyLayout``, ``ocean.util.log.SimpleLayout``
  - ``MessageOnlyLayout`` has been renamed to ``LayoutMessageOnly``
  - ``SimpleLayout`` has been renamed to ``LayoutSimple``
  - Both these layout classes have been moved into ``ocean.util.log.layout.*``

New Features
^^^^^^^^^^^^

``ocean.io.select.client.EpollProcess``
  An application inheriting from EpollProcess can now use different
  EpollSelectDispatcher instances with different EpollProcess instances. To do
  so, refer the usage example and the unit tests block in the EpollProcess
  module.

``ocean.core.Array``
  Added functions ``removePrefix`` & ``removeSuffix`` that return a slice of the
  given array without the specified prefix or suffix respectively.

``ocean.math.IncrementalAverage``
  Added a new struct that allows calculating the average on the fly from a
  stream (without storing the previous values).

``ocean.core.Exception``
  ``throwChained`` allows the user to throw a new exception while chaining
  in an existing one: this can be used for creating a sequence of exceptions
  to trace the source of an error through the program hierarchy.

  ``ExceptionChain`` transforms an exception into an foreach'able data structure
  consisting of the sequence of exceptions accessible via the ``Exception.next``
  pointer.


v1.13 (2014-05-20)
------------------

Migration Instructions
^^^^^^^^^^^^^^^^^^^^^^

``ocean.util.container.map.utils.FileSerializer``, ``ocean.util.container.map.utils.MapSerializer``
  This module has moved to ``ocean.util.container.map.utils.MapSerializer``
  and has been rewritten to use an object oriented interface, making it
  more maintainable and memory friendly. Refer to the documentation on how the
  interface changed.

``ocean.io.select.SelectListener``
  This module has moved to the ``ocean.net.server`` package.

``ocean.io.select.SelectListener.model.*ConnectionHandler*``
  These modules have moved to the ``ocean.net.server.connection`` package.

``ocean.io.select.model.*ListenerPool*``
  These modules have moved to the ``ocean.net.server.connpool`` package.

``ocean.io.select.event``
  This package has been renamed ``ocean.io.select.client``. The following
  command can be used to update any user code which imports these modules:
  ``find src -iname "*.d" -exec sed 's/ocean\.io\.select\.event\./ocean.io.select.client./g' -i \{\} \;``

``ocean.io.select.model.*SelectClient*``
  These modules have moved to the ``ocean.io.select.client.model`` package.

``ocean.io.select.model.IEpollSelectDispatcherInfo``
  This module has moved to the ``ocean.io.select.selector`` package. The
  ``ocean.io.select.model`` package has been removed, as it is now empty.

``ocean.io.device.AsyncFileEpoll``
  This module has been removed as it was only partly documented/working. See #33
  for discussion on a full asynchronous file I/O system.

``ocean.io.serialize.StructLoader``, ``ocean.io.serialize.StructDumper``,
``ocean.io.serialize.model.StructVersionBase``, ``ocean.io.serialize.model.StructLoaderBase``
  StructLoader has been replaced by a interface-compatible class that adds
  support for struct versions. The original loader is still available at
  ``ocean.io.serialize.model.StructLoaderCore``.

  Version support means that each definition of a struct can have a version.
  Upon serialization, that version is put into the serialized data. When this
  data is loaded again, the loader checks whether the requested struct version
  is the same as the one that it was serialized with. If it isn't, a
  semi-automatic conversion to the requested version will be attempted.

  If no version information can be found in a struct (absence of
  ``const StructVersion``), the struct is treated as unversioned and nothing
  changes.

  The version logic is found in ``ocean.io.serialize.model.StructVersionBase`` in
  case you plan to use it outside the loader/dumper classes.

  The StructDumper gained the version aware `length()` method originally found in `DumpArrays`

New Features
^^^^^^^^^^^^

``ocean.util.app.LoggedCliApp``, ``ocean.util.app.VersionedLoggedCliApp``, ``ocean.util.app.VersionedLoggedStatsCliApp``
  These application classes that support tango based logging out-of-the-box can
  now also specify the layouts for the log output. The layouts for the file logs
  and console logs can be specified individually using the keys ``file_layout``
  and ``console_layout`` respectively.

  The following values are currently supported with the layout keys:
  ``messageonly``, ``stats``, ``simple``, ``date`` & ``chainsaw``.  Additional
  layouts can be created by inheriting from the ``Appender.Layout`` class and
  implementing the ``format`` method.

  If a layout has not been explicitly set in the config file, the ``date``
  layout is used for file logs and the ``simple`` layout is used for console
  logs. This corresponds to the default layouts in place before the addition of
  this feature.

``ocean.util.container.map.utils.MapSerializer``
  The helper class SerializingMap and the template mixin MapExtension have been
  added, allowing easy integration of serialization functionality in existing
  map classes.
  Extended the map serializer with version support similar to the struct loader
  and dumper. Includes automatic conversion from older versions to current ones.

``ocean.core.Array``
  Added functions ``startsWith`` & ``endsWith`` to check whether an array
  starts or ends with a specified sub-array respectively.

``ocean.net.email.EmailSender``
  Ability to cc added.

``ocean.core.StructConverter``
  This module allows you to convert a struct A to a similar but not equal
  struct B. You can guide the conversion using converter functions for variables
  that differ between them.

``ocean.io.device.MemoryDevice``
  MemoryDevice behaves like a file but exists only in memory. Useful for when
  you want to test functions that want to operate on a file.

  This was created as an alternative to ``tango.io.device.Array``, whose ``write``
  function has the unreasonable limitation of always appending instead of
  respecting the current seek position and thus not properly simulating a file.

``ocean.core.DeepCopy``
  ``DeepCopy`` has been updated to cover a much broader range of types:
  structs, classes, static and dynamic arrays (including ``void[]`` arrays),
  atomic types and enums.  It will however reject types that cannot effectively
  be deep-copied, such as unions or pointers. Associative arrays currently
  remain unsupported.

``ocean.sys.TimerFD``
  New class wrapping the linux timer fd functions.

``ocean.io.select.client.FiberTimerEvent``
  New class which allows a fiber to be suspended for a specified time.

``ocean.util.log.Stats``
  Added the new templateless base class ``IPeriodicStatsLog``. This can be used
  to implement other types of periodically updating stats loggers. (The existing
  ``PeriodicStatsLog``, which now derives from ``IPeriodicStatsLog``, is rather
  particular in its requirement that the information to be written to the stats
  log is a single struct.)

``ocean.util.log.Stats``
  Added a method ``StatsLog.addSuffix()`` which writes the values of the
  provided struct or associative array to the stats log, appending the specified
  suffix to the name of each individual value. This can be useful in situations
  where you have a set of stats which is repeated for a variable list of
  instances. An example of this kind of usage would be if you had a struct
  containing two fields, counters of bytes and records, and wanted to write one
  instance of this struct to the stats log for each channel in a dht, suffixing
  the name of the dht channel to the name of each individual stats value
  (bytes_campaign_metadata, records_campaign_metadata, bytes_admedia_metadata,
  records_admedia_metadata, etc).


v1.12 (2014-04-01)
------------------

:Dependency: tango v1.0.0 (v1.0.1 recommended)

.. important:: **The repository layout changed!**

   You need to change a few things in your repository:

   * Now the source code for libraries will be stored in ``./src`` too.
     You need to change your library include paths from ``-I./ocean`` to
     ``-I./ocean/src`` (this will apply to other libraries too).  If you are
     using ``script/common.mk``, the changes were done for you already (check
     the migration instructions for extra details).

   * Now git submodules are expected to be in the ``submodules`` subdirectory,
     you can move them like this::

       mkdir -vp submodules
       sed -n 's/^\[submodule "\(.*\)"\]$/git mv \1 submodules\/\1/p' .gitmodules |
               sh -x
       git commit -m 'Move submodules to ./submodules'


Migration Instructions
^^^^^^^^^^^^^^^^^^^^^^

``ocean.io.compress.lzo.c``
  Minilzo C sources files has been removed and the bare C bindings were adapted
  to match the full liblzo2 organization (this only affects you if you use the
  bare C bindings, nothing changed in the higher level D bindings).

  Users are now expected to have the distribution's ``liblzo2-2`` package
  installed for running applications and the ``liblzo2-dev`` package to compile
  them.

``ocean.db.ebtree``
  The whole package was moved to ``ocean.util.container.ebtree``. Also the
  ebtree C sources files has been removed, users are now expected to have the
  the external ``libebtree6`` library installed. This is a custom version of
  the ebtree library that can be found here:
  https://github.com/sociomantic/ebtree

``ocean.util.MemUsage``
  This module has been removed. It wasn't being use and it was outdated.

``script/common.mk``, ``script/mkversion.sh``
  On top of what is said in the *Important* note, you need to do the following
  changes:

  - Now ``-I./src`` is added automatically to the flags, it is strongly
    recommended for you to start importing application project modules without
    including the prefix ``src.``.
  - Update ``.gitignore`` with the new version module location:
    ``./src/Version.d``.
  - Update your module imports for ``Version.d`` to be plain ``import
    Version``.
  - If you use ``mkversion.sh`` directly, remove library base dir parameter and
    provide qualified submodule folder paths instead. Also be aware that the
    template parameter is no longer an option specified by -t, it is now a
    required parameter and should appear after the GC parameter and before the
    libraries.

New Features
^^^^^^^^^^^^

``ocean.text.convert.Integer``
  Add four new integer conversion methods ``toByte``, ``toUbyte``, ``toShort``
  and ``toUshort``, and update ``toInteger`` to use these conversions.  Integer
  conversion now supports all built-in integer types.

``ocean.core.Enum``
  Added opIndex lookup of names / values.

``script/common.mk``
  New target `unittest` provides easy way to run all unit tests for projects on
  machines that have rdmd installed. Just including `common.mk` is enough to add
  it to project.

  Also now makefiles shouldn't provide tango as a dependency or feed them to
  ``mkversion.sh``, as long as they are using Tango v1.0.1 or later. If you are
  using the latest Tango but you still provide a local Tango instance as
  dependency, the local version will be used as before.

  A new *option* was added to enable DMD warnings while compiling, just call
  ``make W=1`` to enable them. We are moving towards to enable warnings by
  default in a non distant future so it is recommended to compile with this
  option from time to time and start squashing warnings sooner than later.

``script/Makd.mak``
  This is a new build system, a replacement for ``script/common.mk`` providing
  all the features from it and much more. At this stage is still considered
  experimental but people is encouraged to try it and report problems. For more
  information please read ``script/Makd.README.rst``.

``ocean.io.select.SelectListener``
  A new public method, ``connectionlog()``, has been added. Calling this method
  causes information about the server's connection pool to be output to the
  module's logger, at level "info". Detailed information about each busy
  connection is logged by the new ``formatInfo()`` method of the
  ``IConnectionHandler`` class. The base class logs the file descriptor of the
  connection's socket, the remote ip and port of the socket, and a flag telling
  whether any I/O errors occurred since the connection was accepted. Derived
  classes may override this method to add further connection-level information.

v1.11 (2014-01-24)
------------------

:Dependency: tango v1.0.0

Migration Instructions
^^^^^^^^^^^^^^^^^^^^^^

``ocean.sys.Epoll``
  Dependency on ISelectClient was removed. Convenience overload for `ctl` method
  that accepted ISelectClient argument was removed. Use other overloads, passing
  ISelectClient members as arguments explicitly.

New Features
^^^^^^^^^^^^

``ocean.text.xml.Xslt``
  A new function `suppressXsltStderrOutput` is added to prevent XSLT parsing
  errors from appearing on the console.


v1.10 (2013-12-20)
------------------

:Dependency: tango v1.0.0

New Features
^^^^^^^^^^^^

``ocean.text.utf.UtfUtil``
  Add two new methods ``truncateAtWordBreak`` and ``truncateAppendEnding``. The
  first method truncates a UTF-8 string to the nearest white space less than a
  maximum length passed parameter. The second method truncates a UTF-8 string
  using the first method and appends an ending string parameter.

``ocean.io.serialize.StringStructSerializer``
  The ``StringStructSerializer`` class takes a new argument in the constructor,
  ``fp_dec_to_display``, specifying the maximum number of decimal digits to show
  for floating point types.

``ocean.io.device.DirectIO``
  New module to perform I/O using Linux's ``O_DIRECT`` flag. Two separate
  classes are provided for input and output because of the complex nature of
  direct I/O, ``BufferedDirectWriteFile`` and ``BufferedDirectReadFile``,
  and they only follow Tango's stream API (but that should be enough for most
  of the needed interaction with other Tango I/O facilities).
  Please read the module documentation for details on when using this module is
  convenient and when it isn't.

``ocean.math.Convert``
  New module that contains methods to round a float, double, or real to an int
  or a long. Rounds x.5 to the nearest integer (the tango functions
  (rndint/rndlong) round x.5 to the nearest even integer).

``ocean.net.email.EmailSender``
  New optional argument bcc added to sendEmail. It can be used for sending
  a blind carbon copy of the email.

``ocean.io.console.AppStatus``
  New optional argument to the constructor that sets the expected time period
  between calls to ``getCpuUsage()`` to support applications that refresh the
  app status window for a period more or less than 1000ms (defaults to 1000ms).

``ocean.util.config.ClassFiller``
  Add the ability to parse list of numbers in config file. The feature can
  be used through providing a number array (e.g ``float[] floats_list``) in
  the config class passed to the ``ClassFiller()``.

``ocean.util.config.ConfigParser``
  Fixed a bug in ``getListStrict()`` where the method could only parse
  ``char[][]`` arrays. The method can now parse other supported multi-line
  values (e.g ``float[]``, ``ulong[]`` and ``bool[]``).


v1.9 (2013-11-15)
-----------------

Migration Instructions
^^^^^^^^^^^^^^^^^^^^^^

``ocean.io.digest.Fnv1``
  Fnv1 hash aliases deprecated. All code which uses them should create its own
  alias of the ``Fnv1Generic`` class as needed.

``ocean.util.container.map.FileSerializer``
  Loading files with version < 2 is not longer supported, since the older
  versions was deprecated a long time ago. If you have a file with
  version < 2, use ocean v1.8.1 to load the map and dump it to get it as
  a file of version 2.

``ocean.util.log.Stats.StatsLog``
  The class is no longer is a template class. Instead the according methods
  became template methods
  The methods `write`, `writeExtra` and `formatExtra` have been removed. Their
  functionality is replaced by the `add` and `flush` functions. After all values
  have been added using the various overloads of `add`, `flush` has to be called
  to finalize the writing.

``ocean.util.log.Stats.PeriodicStatsLog``
  The post log delegate passed to the c'tor now receives a reference to the
  `StatsLog` class. This can be used to add further values to the stats line.
  After the call to the post log delegate, the stats values are flushed and
  written out to the file.

New Features
^^^^^^^^^^^^

``ocean.util.Unittest``
  `enforce` and `enforceRel` methods were added which throw test-specific
  exception class instance with better message formatting than built-in assert.

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

``ocean.text.entities.model.MarkupEntityCodec``
  The `decode` function is now approximately 700% faster.
  The broken `decodeAmpersands` function is removed. Previously, it didn't compile.

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
