Dependencies
============

Dependency | Version
-----------|---------
makd       | v1.3.x
tango      | v1.3.x

Migration Instructions
======================

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


New Features
============

* `ocean.task.util.StreamProcessor`

  Added getter method for the internal task pool.
