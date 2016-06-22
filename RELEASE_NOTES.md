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
