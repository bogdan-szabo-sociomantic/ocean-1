Dependencies
============

Dependency | Version
-----------|---------
tango      | v1.3.x

Migration Instructions
======================

`ocean.util.container.queue.NotifyingQueue`

  A new overload of the `NotifyingQueue.pop` method has been introduced which
  takes a `ContigousBuffer!(Struct)` when `NotifyingQueue` is instantiated
  with a struct type,

  For `NotifyingQueue` instantiated with a struct type, the old `pop()`
  method only taking a byte buffer has been deprecated.

* `ocean.util.serialize.contiguous.Serializer`

  If you have been using partial explicit template argument list
  (``Serializer.serialize!(S)(instance, dst)``) it will need to be replaced
  with fully implicit version (``Serializer.serialize(instance, dst)``) because
  of dmd1 template function overloading glitches.

Removed Symbols
---------------

* `script`

  The (outdated) Makd copy which lived under `script/` has been removed.


* `tango.sys.consts.fcntl`

  This module was deprecated since inclusion in ocean (1.25), as it was deprecated
  by tango 1.3. It is believed to be unused.

* `tango.sys.consts.socket`

  This module was deprecated since inclusion in ocean (1.25), as it was deprecated
  by tango 1.3. It is believed to be unused.

* `ocean.core.DeepCopy`

  This module was deprecated in ocean 1.24


Deprecations
============

* `tango.util.log.Config`

  This module automatically adds a console output to the root logger.
  Besides being rarely needed, it is unreliable as it depends on the module constructor
  call order.  User wishing the retain the behaviour should put its `static this()` code
  in their `main.d` source file.

* `tango.util.log.Trace`

  This module did not provide anything but an `alias Trace Log` and a `public import`
  to a (now deprecated) module.  The documentation even recommended to use another
  module.

* `ocean.util.app.CommandLineApp`,
  `ocean.util.app.ConfiguredApp`,
  `ocean.util.app.LoggedCliApp`,
  `ocean.util.app.VersionedCliApp`,
  `ocean.util.app.VersionedLoggedCliApp`,
  `ocean.util.app.VersionedLoggedStatsCliApp`

  The menagerie of application base classes have been deprecated. All programs
  deriving from these classes should change to use either `CliApp` or
  `DaemonApp`.

* `ocean.util.log.Stats`

  The classes `PeriodicStatsLog` and `IPeriodicStatsLog` have been deprecated.
  Applications using these classes should be migrated to use the periodic stats
  logging feature of the `DaemonApp` application base class. `DaemonApp` has a
  method called `onStatsTimer()` which is called every 30s
  (`IStatsLog.default_period`). Applications should override this method and use
  the `StatsLog` instance (`this.stats_ext.stats_log`) to write their stats.

* `ocean.text.convert.Hash.isHex`, `ocean.text.convert.Hash.hexToLower`

  These methods were moved to a new module `ocean.text.convert.Hex`.

New Features
============

* `ocean.core.Traits`

  New function, `copyClassFields`, which is identical to `copyFields` but
  doesn't take its arguments using `ref`. This addition is primarily needed
  as a way to fix `Deprecation: this is not an lvalue` warnings in other
  libraries that come from using old `copyFields` with class `this` as an
  argument.

* `ocean.util.log.AppendSysLog`

  A new log appender which outputs to the system log
  ([syslog](http://linux.die.net/man/3/syslog)).

  Note that the name of this class is very similar to the old
  `tango.util.log.AppendSyslog`. The tango class is scheduled to be deprecated,
  though, so the potential for confusion will only exist for a limited time.

* `ocean.util.log.Config`

  A new option has been added to the logger config, allowing a logger's output
  to be sent to syslog (possibly in addition to the console and/or a normal log
  file). To configure this, just add `syslog = true` to the logger configuration
  section of your `config.ini` file.

  The big advantage of writing to syslog, instead of to a file, is that file
  writes are blocking, whereas syslog writes just require an in-memory copy: the
  actual writing of log messages to disk is handled by the syslogd process.

* `ocean.util.app.CliApp`

  This new application base class should be inherited by all applications which
  do not run as daemons, that is apps which run either as one-shot tools or
  `cron`-triggered jobs.

  `CliApp` has the same features (i.e. extensions) as the older
  `VersionedCliApp`; the only difference is in the way that optional settings
  are passed to the constructor.

  The goal is to have a single port-of-call in ocean for the features required
  by such apps, in contrast to the current status quo, where applications are
  using all sorts of different app base classes and extension on a fairly random
  basis. With a single, universal application base class, we will simplify the
  writing of new apps, simplify the updating of existing apps to the latest
  recommended practices, and simplify the maintenance of the code in ocean.

* `ocean.core.TypeConvert`

  Added new utility `arrayOf` which helps to create array literals with
  specific element type instead of relying on type deduction. One of most
  important use cases for it is creating arrays of `Typedef` types in a way that
  is compatible with DMD2 - implicit casting of base type to `Typedef` struct
  doesn't work.

* `tango.core.Array`

  `sort` function now returns its argument after sorting. This is done to be
  able to replace built-in sort which is needed for D2 migration.

* `ocean.text.convert.Hex`

  New method `hexToBin` is added to convert a string of hex digits to a byte array
  (only byte per two characters).

* `ocean.util.serialize.contiguous.Serializer`

  `Serializer.serialize` has new single-argument overload which serializes
  given contiguous struct instance in place, resetting all its array
  pointers to null. This take advantage of `Contiguous` data layout and is
  both very fast and doesn't require new memory buffer.

* `ocean.util.app.DaemonApp`

  The `OptionalSettings` struct has been extended with the field
  `reopen_signal`, which determines the signal number which is handled by the
  `ReopenableFilesExt` to reopen all registered files (typically used for log
  rotation). The default signal is SIGHUP, but may now be configured as the
  application wishes.
