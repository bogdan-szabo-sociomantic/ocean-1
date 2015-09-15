Dependencies
============

Dependency | Version
-----------|---------
tango      | v1.2.1

Migration Instructions
======================

Removed Deprecated Modules
--------------------------

* `ocean.core.DeepCopy`

  Deprecated in favor of `ocean.util.serialize.contiguos.Util.copy` in v1.22

* `ocean.core.ErrnoIOException`

  Deprecated in favor of `ocean.sys.ErrnoException` in v1.22

* `ocean.text.url.PercentEncoding`

  Deprecated as it was empty in v1.23

* `ocean.util.Config`

  Deprecated in v1.23

* `ocean.util.container.queue.SimplifiedFlexibleRingQueue`

  Deprecated in favor of `ocean.util.container.queue.FlexibleRingQueue` in v1.23

Removed Deprecated Symbols
--------------------------

Removed Symbols
---------------

Deprecations
============

* `TokyoCabinetExtString.toString`

  Deprecated in favor of `TokyoCabinetExtString.toMString` because D2 runtime
  requires `toString` to return immutable strings which was not intended in
  this case.

New Features
============

* `util.container.map.model.BucketElementMallocAllocator`

  Added a new allocator (previously lived in alligator) which allocates map
  elements using `malloc()` and recycles them using `free()`.

* `util.container.map.model.*Allocators`

  Added helper functions to create an allocator instance which suitable to be
  used with a given map type.

* `util.container.map.Map`

  Added an overloaded constructor to the `StandardKeyHashingMap` class which
  allows usage of a custom allocator instead of the default one.
