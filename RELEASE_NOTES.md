Dependencies
============

Dependency | Version
-----------|---------
makd       | v1.3.x
tango      | v1.3.x

Migration Instructions
======================

* `ocean.task.util.StreamProcessor`

  All uses of `max_tasks` has been deprecated, the task pool is now unlimited by
  default. Use `getTaskPool` and set a limit manually if you want to limit it.

Deprecations
============

* `ocean.task.util.StreamProcessor`

  Constructor that expects `max_tasks`, `suspend_point` and `resume_point` has
  been deprecated in favor of one that takes a `ThrottlerConfig` struct.

New Features
============

* `ocean.task.util.StreamProcessor`

  Added getter method for the internal task pool.
