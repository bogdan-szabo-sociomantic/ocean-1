Dependencies
============

Dependency | Version
-----------|---------
makd       | v1.3.x
tango      | v1.3.x

Migration Instructions
======================

* `ocean.text.Ascii`

  `toLower` and `toUpper` functions have been changed to expect a buffer 
  array as a second argument (it will be expanded if necessary). Previously
  it required a pre-allocated slice of necessary size. As a side effect,
  any code that uses static array as second argument will stop compiling and
  will need to be adjusted to use copy + in-place overload of these functions.

* `ocean.time.MicrosecondsClock`

  This class no longer implements the `IMicrosecondsClock` interface, which is
  scheduled to be deprecated. All of its members are now static.

* `ocean.core.Exception`

  `ReusableExceptionImplementation` was changed to override `message` method
  instead of `toString` to be more compatible with what D2 runtime expects
  from exception `toString` methods. Use `ocean.transition.getMsg` helper
  to reliably get exception message no matter what ocean version is used and
  whenever it is D1 or D2.

* `ocean.util.log.Config`

  When the `console` flag of the `Config` instance is set to true, instead of
  creating an `AppendConsole` appender, `configureLoggers()`,  now creates an
  `AppendStderrStdout`. This new log appender writes messages for levels `warn`,
  `error`, and `fatal` to `stderr` and `info` and `trace` to `stdout`. This
  change of behaviour is not expected to affect any applications.

* `ocean.core.Array_tango`

  `sort` function was rewritten using a different template declaration so that
  it forces the argument to be a dynamic array. This change affects both D1
  and D2. It is not sure if this can cause any breakage

Deprecations
============

* `tango.*`

  All tango modules are now marked deprecated. Their ocean replacements have
  been introduced in ocean release v1.28, check its migration notes for details
  on how to update code.

* `ocean.util.log.Stats : StatsLog`

  The `StatsLog` constructors which do not require a `Config` instance have been
  deprecated. Usage can trivially be replaced by constructing a `Config`
  instance, as follows:

  ```D
    new StatsLog(file_count, max_file_size, file_name, name);
    // -->
    new StatsLog(new StatsLog.Config(file_name, max_file_size, file_count), name);

    new StatsLog(file_name, name);
    // -->
    new StatsLog(new StatsLog.Config(file_name), name);
  ```

* `ocean.util.log.Stats : IStatsLog`

  This class has been deprecated. All usage should be replaced by directly using
  `Statslog` instead.

* `ocean.io.selector`

  This whole package has been deprecated. It is unused.

* `ocean.time.MicrosecondsClock`

  The `now_us_static()` method has been deprecated. `now_us()` is now static, so
  can be used instead.

* `ocean.io.select.client.IntervalClock`

  This whole module is deprecated. All time getting functionality can be
  replaced with `time(null)` or the higher-precision functions in
  `ocean.time.MicrosecondsClock`.

* `ocean.io.console.AppStatus`

  The constructor which requires an `IAdvancedMicrosecondsClock` reference is
  deprecated. Use the other constructor instead, which accepts all the same
  arguments except the clock.

* `ocean.db`

  This package has been removed. It was only used in one project so has been
  moved into that repo.

* `ocean.io.console.readline.Readline.readline()`

  Deprecated the buggy, allocating versions of the `readline()` method.
  The new replacing method takes both the prompt string as well as the input-
  reading string as mutable buffers. The prompt needs to be a mutable buffer
  as a null terminated character might be added to the string in order to
  pass it to the C readline function.

New Features
============

* `ocean.util.container.cache.PriorityCache`

  Added `getHighestPriorityItem()` and `getLowestPriorityItem()` to retrieve
  the items with the highest and the lowest priorities.

* `ocean.util.container.cache.PriorityCache`

  Added a an opApplyReverse() method.

* `ocean.sys.Process`

  D2 only. Now can use pre-existing `istring[] arguments` array directly without
  having developer to re-create it as `cstring[] arguments` array manually. 

* `ocean.util.container.queue.LinkedListQueue`

  Added a new optional `gc_tracking_policy` template parameter which allows
  defining the gc scanning policy for the items allocated in the queue.

* `ocean.util.container.queue.LinkedListQueue`

  Added a new `isRootedValues()` method which returns whether the queue
  allocated items are added to the gc scan range.

* `ocean.text.xml.c.LibXslt`

  Add low-level functions to set the LibXslt maximum recursion depth.

* `ocean.util.app.ext.StatsExt`

  A new method, `newStatsLog()` has been added. This method allows the user to
  create `StatsLog` instances in addition to the one which is created
  automatically by the `StatsExt` and stored in its `stats_log` member. The new
  stats logger is configured according to the default settings and will be
  registered with the application's `ReopenableFilesExt`, if present, for log
  rotation. (The ability to create multiple stats loggers is desired by some
  applications, so this method has been added to enable them to easily create
  properly configured instances.)

* `ocean.net.http.HttpException`

  Custom enforce method for using multiple strings combined with a status code.

* `ocean.sys.Inotify`

  This new class wraps the inotify linux tool (Linux monitoring filesystem
  events API), see http://man7.org/linux/man-pages/man7/inotify.7.html

* `ocean.io.select.client.FileSystemEvent`

  This new class makes use of the `ocean.sys.Inotify` implementation to
  provide a simple and efficient way to monitor files (or directories)
  asynchronously. The supported events can be found in `ocean.sys.linux.inotify`.
  See `test.filesystemevent.main` as example of `FileSystemEvent` usage.

* `ocean.core.MessageFiber`

  An exception message may now be passed to `resume()`, which is then returned
  (not thrown for compatibility reasons) by the waiting `suspend()` call.
  Previously this was disallowed.

* `ocean.time.MicrosecondsClock`

  New functions have been added, to convert the time specified as a `time_t` or
  `timeval` to a full date/time representation, as a `tm` or `DateTime` struct.

* `ocean.util.container.ebtree.c.ebtree`

  `eb_root` can now be configured to accept only unique nodes. If this is
  enabled and a node with an existing key is passed to one of the `eb*_insert`
  functions then the function will not add the new node but return the existing
  one, performing an "add new or get existing" operation.
  Note that this feature was always documented for the `eb*_insert` functions.
  It is currently not supported by the `EBTree*` classes because it would
  require a major interface change to return the existing node if enabled.

* `ocean.util.cipher.gcrypt.c`

  Added bindings for message digest (aka hash), random number and gpgerror
  functionality of libgcrypt.

* `ocean.util.cipher.MessageDigest`

  Convenience wrapper for libgcrypt message digest functions with HMAC support.

* `ocean.util.log.AppendStderrStdout`

  This new log appender writes messages for levels `warn`, `error`, and `fatal`
  to `stderr` and `info` and `trace` to `stdout`.
