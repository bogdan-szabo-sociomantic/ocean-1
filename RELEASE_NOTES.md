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


Deprecations
============

* `tango.text.Arguments`

  This module is now deprecated. All its functionality has been moved to
  `ocean.text.Arguments`.

New Features
============

* `ocean.io.model.ISuspendableThrottler`

  `ISuspendableThrottler` now contains the method `removeSuspendable` to remove an
  `ISuspendable` from registered suspendables.

* `tango.core.UnitTestRunner`

  When run in verbose mode, the unittests now outputs the memory consumption
  (before, after, and the difference).  In order to make the tests reliable,
  a GC collection is done before each module is tested.

* `ocean.util.container.MallocArray`

  A new module which contains a collection of functions that aid in creating
  and manipulating malloc-based arrays.

* `ocean.util.app.ext.TimerExt`

  Added `registerMicrosec()`, which accepts integer µs time values to allow
  using the precise time unit that is used by the underlying library calls.

* `ocean.util.app.DaemonApp`

  This new application base class should be inherited by all long-running,
  daemon-type applications.

  The goal is to have a single port-of-call in ocean for the features required
  by such apps, in contrast to the current status quo, where applications are
  using all sorts of different app base classes and extension on a fairly random
  basis. With a single, universal application base class, we will simplify the
  writing of new apps, simplify the updating of existing apps to the latest
  recommended practices, and simplify the maintenance of the code in ocean.

  The old application base classes will be deprecated in the next release, along
  with helpers which are no longer required (e.g. `PeriodicStatsLog` and
  `AppendSyslog`).

  `DaemonApp` provides the same features as the catchily-named
  `VersionedLoggedStatsCliApp`, with the following additions:

    * More extensions: `TimerExt`, `SignalExt`, and `ReopenableFilesExt`.
    * The timer extension is used to trigger stats logging once every 30s (as
      defined by `IStatsLog.default_period`). The protected method
      `onStatsTimer()` should be overridden by the derived application class to
      write the required stats via `this.stats_ext.stats_log`. (Applications
      using a `PeriodicStatsLog` or which implement their own timer to trigger
      stats output will need to be adapted to the new, more automated system.)
    * The presence of the signal and reopenable files extensions causes the
      loggers (including the stats logger) to use the simple file appender, in
      place of the old `AppendSyslog` appender which handles log rotation and
      compression. This means that your log files will no longer be
      automatically rotated. However, the `DaemonApp` base class sets up
      everything you need in order to use the system `logrotate` facility
      instead: `SIGHUP`, sent to the application, causes all open log files to
      be reopened. `logrotate` can then be configured to send this signal when
      it rotates your log files.

      Example logrotate configuration file (usually located in
      `/etc/logrotate.d`) for a program called `myapp`:

      ```
          /srv/myapp/log/*.log
          {
              rotate 10
              missingok
              notifempty
              delaycompress
              compress
              size 500M
              sharedscripts
              postrotate
                  /usr/bin/killall -HUP myapp
              endscript
          }
      ```

      (`logrotate` is favoured over tango's `AppendSyslog` as bugs have been
      found in the latter which are not present in the former. It is generally
      regarded as safer to use a massively tested system component like
      `logrotate`, rather than a reimplemented (and directly equivalent!)
      replacement in our libraries.)

  **Important note** on `DaemonApp`'s event handling requirements:

  The `DaemonApp` class does not currently interact with epoll in any way
  (either registering clients or starting the event loop). This is a deliberate
  choice, in order to leave the epoll handling up to the user, without enforcing
  any required sequence of events. (This may come in the future.)

  An epoll instance must be passed to the constructor, as this is required by
  the `TimerExt` and `SignalExt`. The user must manually call the
  `startEventHandling()` method, which registers the select clients required by
  the extensions with epoll (see [`DaemonApp`'s usage example](https://github.com/sociomantic/ocean/blob/e87b3e0e735aaaa8b603315e02127ac1fdbe27c0/src/ocean/util/app/DaemonApp.d#L549)).
  This method must be called before the application's main event loop begins --
  the signal and timer event handlers will never become unregistered, so the
  event loop will never exit, after that point.

* `ocean.util.cipher.gcrypt.Twofish`

  Added Libgcrypt bindings with support for Twofish.

* `ocean.net.email.EmailSender`

  A new overload of the `sendEmail()` function has been added. This new function
  takes email recipients (as well as `cc` * `bcc` lists) in the form of a 2D
  buffer (where each email address is in a separate index).

* `ocean.util.container.queue.NotifyingQueue`

  Now supports types other than a struct as template parameter.

* `ocean.text.convert.DateTime`

  The `timeToUnixTime()` function now also supports conversion of a timestamp
  string from the Internet Message Format (e.g. `Sun, 09 Sep 2001 01:46:40 UTC`)
  to its equivalent Unix timestamp value.

