Dependencies
============

Dependency | Version
-----------|---------
makd       | v1.3.x
tango      | v1.3.x

Migration Instructions
======================

* `ocean.text.convert.Float`

  A new `format` method has been introduced, which formats a floating point value according to
  a provided format string, which is a subset of the one passed to Layout.
  It mimics what Layout will do, with the exception that "x" and "X" format string aren't handled
  anymore as the original output wasn't correct.


Deprecations
============

* `ocean.task.util.StreamProcessor`

  * Constructor that expects `max_tasks`, `suspend_point` and `resume_point` has
  been deprecated in favor of one that takes a `ThrottlerConfig` struct.

  * `ThrottlerConfig.max_tasks` and the constructors which accept a `max_tasks`
  argument have been deprecated. New constructors have been added which do not
  expect or use `max_tasks`, instead creating an unlimited task pool. If you
  want to limit the maximum number of tasks in the pool, use `getTaskPool` and
  set a limit manually.

* `ocean.text.util.StringC`

  The function `toCstring()` is now deprecated in favour of `toCString()` (note
  the uppercase `S`).

* `ocean.text.convert.Float`

  `parse` overloads for `version = float_dtoa` and `format` overload
  for `version = float_old` have been deprecated.

* `ocean.util.cipher.gcrypt.core.Gcrypt`

  The `Gcrypt` template has been deprecated, either `GcryptWithIV` or
  `GcryptNoIV` should be used, depending on if your desired encryption mode
  requires initialization vectors or not.

* `ocean.util.serialize.contiguous.VersionDecorator`

  The `VersionDecorator` defined in this module is deprecated.
  The `VersionDecorator` in the `MultiVersionDecorator` module of the same package
  should be prefered, as it handles multiple version jump without runtime performance.

* `ocean.io.serialize.XmlStructSerializer`

  This unmaintained module is deprecated.

* `ocean.text.xml.Xslt`, `ocean.text.xml.c.LibXslt`, `ocean.text.xml.c.LibXml2`

  The XSLT processor implemented here is not generic and is thus being removed
  from ocean. It will be moved to another repository.

* `ocean.util.cipher.gcrypt.AES`

  The `AES` alias has been deprecated in favor of the equivalent `AES128`.

New Features
============

* `ocean.sys.socket.model.ISocket`

  Add `formatInfo` method which formats information about the socket into the
  provided buffer

* `ocean.task.util.StreamProcessor`

  Added getter method for the internal task pool.

* `ocean.io.select.client.TimerSet`

  The `schedule()` method now returns an interface to the newly scheduled event
  (`IEvent`), allowing it to be cancelled.

* `ocean.task.Task`

  Task has gained methods `registerOnKillHook`/`unregisterOnKillHook` that can be
  used to register/unregister callback hooks to be called when the Task is killed.

* `ocean.util.cipher.gcrypt.AES`

  Additional aliases for 192- and 256-bit AES ciphers have been added.

* `ocean.time.timeout.TimeoutManager`

  TimeoutManager now has a constructor that takes an optional bucket element
  allocator. The intended usage is to allow the use of an alternative allocator,
  e.g. BucketElementFreeList. This can reduce the number of GC allocations
  performed. The existing constructor uses the default bucket allocator of
  map (BucketElementGCAllocator), which will cause garbage collections.
