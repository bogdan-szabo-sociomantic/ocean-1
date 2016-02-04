Dependencies
============

Dependency | Version
-----------|---------
tango      | v1.3.x

Migration Instructions
======================

`ocean.util.container.queue.NotifyingQueue`

  A new overload of the `NotifyingQueue.pop` method has been introduced which
  takes a `ContigousBuffer!(Struct)` and a `ubyte[]` buffer when
  `NotifyingQueue` is instantiated with a struct type,

  For `NotifyingQueue` instantiated with a struct type, the old `pop()`
  method only taking a byte buffer has been deprecated.

* `ocean.sys.CpuAffinity`

  - `CpuAffinity.set()` now throws `ErrnoException` on failure. It used to
    return `false` before; the return type is now `void`.

* `ocean.io.select.protocol.fiber.FiberSelectWriter`

  The following methods can now throw `IOError`:

    * `flush()`
    * `cork(bool)` (the setter method)

  Before these methods didn't throw. Now they do, especially if the socket file
  handle is invalid. A known case where this happens is if a server application
  attempts to enable cork for a client socket `FiberSelectWriter` object
  *before* handing the socket over to the writer object. This is wrong usage and
  a bug in the application code, which is not silently accepted any more.

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

New Features
============

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
