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
