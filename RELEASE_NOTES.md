Dependencies
============

Dependency | Version
-----------|---------
tango      | v1.1
dmd1       | v1.076.s2

Migration Instructions
======================

* `ocean.io.serialize.StructDumper`
  `ocean.io.serialize.StructLoader`

  This is architectural change and is likely to require careful intervention.

  In places where you have been using `StructLoader` to deserialize versioned
  data from the DHT (or other external source), replace it with
  `ocean.util.serialize.contiguous.VersionDecorator`. Contrary to `StructLoader`
  this new helper will return deserialized buffer completely stripped of any
  version data. Any further operations on it must assume lack of version number
  and use `ocean.util.serialize.contiguous.Deserializer` instead. In cases
  where `StructLoader.loadCopy` (or similar method) was used to effectively
  do a deep copy of deserialized struct buffer, consider using
  `ocean.util.serialize.contiguous.Util.copy` instead.

  Same applies to `StructDumper`, which is replaced by `contiguous.Serializer`
  However, version-aware dumping of data is done by
  `ocean.util.serialize.contiguous.VersionDecorator` too.

  You may also need to change some of your buffers from `char[]` or `void[]` to
  `Contiguous!(KrillStruct)` type as new package is considerably more type-safe
  at cost of requiring more attention to used type from the user.

  Ideally as the result only place in your application which uses version-aware
  utilities would be small part of code that operares with DHT and everything
  else would use plain (de)serialization utilities.

  If help is needed or in case of any questions contact Mihails

* `ocean.util.config.ConfigParser`

  The return value of the `getList` method has been fixed. It used to
  incorrectly return true/false, but now returns a dynamic array.

* `ocean.net.email.EmailSender`

  The method sendEmail has been changed to have contain an optional
  Reply To header and this change breaks the API. Since the whole
  module is an hack and only one Application is using all the optional
  parameters this is the easiest solution.

* `scripts/git-rev-desc`

  This script was removed completely. Please use this command instead to get
  a description of the revision:

  ```sh
  cd $1 && git describe --dirty=$2
  ```

Deprecations
============

* `ocean.text.convert.Layout`

  The `print` and `vprint` methods from this module are now deprecated in favour
  of the methods `format` and `vformat` respectively in the
  `tango.text.convert.Layout` module. Applications using either
  `Layout!().print()` or `Layout!(char).print()` need to update to use the
  methods from tango instead. Using the simpler alias in
  `tango.text.convert.Format` is recommended:

  ```d
  import tango.text.convert.Format;

  char[] buf;
  buf = Format.format(buf, "Hello {}", "world");
  ```

* `ocean.io.serialize.StructDumper`
  `ocean.io.serialize.StructLoader`
  `ocean.io.serialize.model.StructLoaderCore`
  `ocean.io.serialize.model.StructVersionBase`

  All this modules have been completely deprecated in favor
  of `ocean.util.serialize.contiguous.*`. Read
  https://github.com/sociomantic/ocean/wiki/Serialization-package-update
  for explanations and migration instructions for specific details


New Features
============

* `ocean.sys.SignalFD`, `ocean.io.select.client.SignalEvent`

  A new method, `register()`, has been added. This allows the set of signals
  which is handled by the signal fd / signal event to be extended after
  construction. (Previously the complete list of signals to be handled was
  required by the ctor.)

* `ocean.util.app.ext.SignalExt`, `ocean.util.app.ext.model.ISignalExtExtension`

  This new application extension adds an infrastructure for registering signal
  handler methods with the application. The `SignalExt` instance must be
  registered with epoll in order to begin handling signals -- it contains an
  instance of `SelectEvent`, accessible via the `event()` method, which can be
  registered with epoll. Once this is done and the epoll event loop is running,
  any handlers (which must implement `ISignalExtExtension`) registered with the
  `SignalExt` will be notified upon receipt of the specified signals by the
  application.

* `ocean.util.log.Stats`

  The number of rotated stats log files after which compression begins can now
  be configured via the `start_compress` field in the `[STATS]` config section.
  The corresponding variable is `IStatsLog.Config.start_compress`. The default
  (which is unchanged) is to start compressing after 4 rotated stats log files.

* `ocean.util.log.Config`

  A new overload of `configureLoggers()` now allows loggers to be configured
  with user-created appenders. (Previously, the `AppendSysLog` was always used.)

* `ocean.util.log.Stats`

  A new constructor now allows loggers to be configured with user-created
  appenders. (Previously, the `AppendSysLog` was always used.)

* `ocean.util.app.ext.ReopenableFilesExt`

  This new application extension allows a set of registered files to be reopened
  upon calling the `reopenAll()` method. The extension cooperates with the
  `SignalExt`, allowing the registered set of files to be reopened when a
  specific signal is received by the application.
