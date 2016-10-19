Dependencies
============

Dependency | Version
-----------|---------
makd       | v1.3.x
tango      | v1.3.x

New Features
============

* `ocean.util.config.ConfigFiller`

  Provides the same functionality as the old `ClassFiller`, but it's
  extended to support `struct`s too.

* `ocean.util.container.queue.LinkedListQueue`

  Added the ability to walk over a `LinkedListQueue` with a foreach statement.
  It will walk in order from head to tail.

Deprecations
============

* `ocean.util.config.ClassFiller`

  Deprecated in favour of the new `ConfigFiller` which provides the
  same interface.
