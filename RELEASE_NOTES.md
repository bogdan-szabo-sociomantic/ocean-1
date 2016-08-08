Dependencies
============

Dependency | Version
-----------|---------
makd       | v1.3.x
tango      | v1.3.x

Migration Instructions
======================

* `ocean.io.select.client.Scheduler`

  This module has been moved to `ocean.io.select.client.TimerSet`. The class
  template `Scheduler` has likewise been renamed to `TimerSet`.

* `ocean.util.app.ext.StatsExt`

  StatsLog instances created by `newStatsLog` will be named according to the file to which
  they write.  This means that the name of the default `StatsLog` instance will change from
  "Stats" to (by default) "log/stats.log".

* `ocean.text.convert.Integer_tango`

  `format` and `formatter` are now templated on the integer type they get as an argument,
  allowing to properly format negative numbers into their non-decimal
  (binary, octal, hexadecimal) representation.
  In addition, passing an `ulong` value which is > `long.max` with format "d" will now
  be correctly formatted (before it resulted in a negative value and required "u" to be used).

* `ocean.util.serialize.model.VersionDecoratorMixins`

  `VersionHandlingException` has been changed to avoid allocating a
  new message any time a conversion fails.

* `ocean.util.log.Config`

  There was a bug in the way loggers were configured during application startup,
  which could potentially cause parent loggers to override the configuration of
  child loggers. This bug has now been fixed, but if your application somehow
  relied on the buggy behaviour (unlikely, because if it did, you would have
  realised it by now), then this fix could cause a difference in the number of
  logs emitted. The number could either increase or decrease depending on the
  configuration.

* `ocean.transition`

  `enableStomping` function now can't be called on arrays of `immutable` or
  `const` elements. This may cause compilation errors but any code which
  is subject to it was triggerring undefined behaviour and must be fixed
  with uttermost importance.

Deprecations
============

* `ocean.time.Ctime`

  This is a very simple module. The reason for deprecation is it comes from
  Tango but it lacks any copyright / licensing information, so to be safe it
  will be removed in v2.0.0.

  There is no inmediate replacement for it (as it was mostly unused), so you'll
  probably have to implement the functionality yourself (or look for similar
  functionality in other `ocean.time` modules).

* `ocean.io.stream.Bzip` `ocean.util.compress.c.bzlib` `ocean.util.cipher.RC6`

  These modules are unused and have some patent notices that are worrying and
  will be removed in v2.0.0.

  There is no immediate replacement for them (as they were mostly unused), so
  you'll probably have to implement the functionality yourself (or look for
  similar functionality in other, for the crypto stuff probably the gcrypt
  bindings).

* `ocean.util.VariadicArg`

  This module is only used by one team and has been moved to Thrusterproto.

* `ocean.io.compress.lzo.c.lzo_crc`

  This module contained functions that are already present in
  `ocean.io.compress.lzo.c.lzoconf`. Just import this module instead.

* `ocean.io.model.ISuspendableThrottler`

  The single `throttle` method has been deprecated in favor of two distinct
  new methods - `throttledSuspend` and `throttledResume`. The new API is
  supposed to allow using fibers as the implementations of `ISuspendable`
  without any risk that the throttler will reach the limit condition and try
  suspending a data producing fiber while executing another fiber (it is only
  legal to suspend a fiber from inside itself).

* `ocean.io.text.Regex`

  This module is basically unmaintained and we have a replacement which is
  probably more efficient, flexible and maintained: `ocean.text.regex.PCRE`

* `ocean.io.stream.Patterns`

  This module was unused and unmaintained, so it is deprecated.

* `ocean.util.cipher: ChaCha, RC4, RC6, Salsa20, TEA, XTEA`

  All deprecated in favour of using the `ocean.util.cipher.gcrypt` package
  instead. It's planned to gradually remove all the old Tango `cipher` package,
  so you might want to start replacing other modules too.

* `ocean.util.cipher.gcrypt: MessageDigest, HMAC`

  `HMAC` has been moved to a separate module, `ocean.util.cipher.gcrypt.HMAC`.
  The `HMAC` class in `ocean.util.cipher.gcrypt.MessageDigest` is deprecated.

  `MessageDigest.hash()` and `HMAC.hash(void[][] ...)` are deprecated and
   replaced with `calculate(`ubyte[][] ...`)`.  This is to avoid an implicit
   cast from `void[][]` to `void[]` when calling the function, which causes a
   wrong hash result, and the error is hard to find.

* `ocean.io.select.client.EpollProcess.ProcessMonitor`

  All references to the ProcessMonitor class should be removed. It existed
  only as a workaround for a bug in EpollProcess, but is no longer required.

New Features
============

* `ocean.io.stream.Buffered`

  User of BufferedOutput now can be notified via provided delegate
  when the BufferedOutput has flushed data to upstream conduit.

* `ocean.core.MessageFiber` `ocean.io.select.fiber.SelectFiber`

  Now it is possible to create both `MessageFiber` and `SelectFiber` wrapping an
  already existing `core.thread.Fiber` instance instead of always allocating
  a new one. It has also become possible to change the underlying fiber
  instance of an already created `MessageFiber` / `SelectFiber`.

* `ocean.io.select.EpollSelectDispatcher`

  Now it is possible to supply a custom delegate to `EpollSelectDispatcher`'s
  constructor which will be run once before the event loop starts and
  subsequently each time an event loop select cycle finishes.

* `ocean.task`

  New package providing a set of modules for working with tasks.

  `ocean.task.Task` defines the new "task" abstraction which is essentially:

    1. a class encapsulating a function dedicated to doing some specific job
    2. the initial data required by that function.

  This makes it possible to allocate many more tasks than fibers (which need a
  rather large stack space to work reliably) and to execute them without fear of
  a memory consumption explosion.

  `ocean.task.Scheduler` is supposed to replace `EpollSelectDispatcher` in the
  role of the main "supervisor" in applications. It still uses epoll internally,
  but also takes care of distributing scheduled tasks over its internal
  fiber pool and is exposed as a global singleton to make the application API
  less burdened with manually passing the same reference around. Contrary to the
  `EpollSelectDispatcher` + `SelectFiber` combo, it is also capable of handling
  tasks that are not bound to any registered event.

  `ocean.task.extensions` is a package with various optional extensions that
  affect basic the functionality and/or semantics of task classes. To use them,
  simply use the template `TaskWith` as a base class for your application's task
  classes and supply the desired extensions as template arguments.

  `ocean.task.TaskPool` provides the simplest way to start using the new system
  with minimal customization while still maintaing decent performance. It
  implements a pool of reusable task objects that automatically get recycled
  when their main function exits. It also supports copying an arbitrary set of
  initial arguments into the task by forwarding them to the `copyArguments`
  method, if it is present in the application task class.

  `ocean.task.util.Timer` contains time-related helper functions for use with
  tasks. Currently, it only contains a single function, `wait()`, but more may
  be added in the future. (This module is an example of how having a global
  scheduler singleton makes it possible to implement a fiber waiting function
  which requires neither adding new fields to classes nor passing the fiber
  reference around (which is necessary with `FiberTimerEvent`).)

  `ocean.task.util.StreamProcessor` is a more specialized version of a task
  pool for the following (common) situation:

    * The application reads data from one or more arbitrary input streams.
    * For each piece of data read, a processing task is spawned.
    * The input streams must be throttled based on the number of queued tasks.

  `StreamProcessor` handles all of the above.

* `ocean.io.select.client.TimerSet`

  Now it is possible to supply `null` instead of a valid epoll instance as the
  constructor argument. In that case, the timer scheduler will use the global
  epoll instance defined by `ocean.task.Scheduler` for all event
  (de)registration.

 * `ocean.util.config.ConfigParser`

   The iterator returned by `iterateCategory()` now supports `foreach` iteration
   over the values, too. The type of the values of the category can be
   specified as a template parameter; all values are then converted to that
   type during iteration.

* `ocean.io.serialize.StringStructSerializer`

  Introduced an overload of the `StringStructSerializer` serializer
  which takes an array of known timestamp field names.
  If a field matches one of the names and implicitly converts to `ulong`,
  an ISO formatted string will be emitted in parentheses next to the value of
  the field (which is assumed to be a unix timestamp).

  Bugfix: Trailing spaces are no longer emitted for arrays with length zero.

* `ocean.util.cipher.gcrypt.AES`

  Added libgcrypt AES (Rijndael) algorithm with a 128 bit key.

* `ocean.util.config.ClassFiller`

  In the ClassIterator, a new `opApply()` function has been added to provide
  foreach iteration only over the names of the matching configuration
  categories.
