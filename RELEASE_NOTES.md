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

New Features
============

* `ocean.task.util.StreamProcessor`

  Added getter method for the internal task pool.

* `ocean.io.select.client.TimerSet`

  The `schedule()` method now returns an interface to the newly scheduled event
  (`IEvent`), allowing it to be cancelled.
