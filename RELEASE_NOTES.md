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
  `DeepReset` utility from the same module is moved to `ocean.util.DeepReset`

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

* `ocean.io.select.protocol.generic.ErrnoIOException`

  Removed deprecated `IOWarning.assertEx` and two `IOWarning.opCall` overloads


Removed Symbols
---------------

Deprecations
============

* `TokyoCabinetExtString.toString`

  Deprecated in favor of `TokyoCabinetExtString.toMString` because D2 runtime
  requires `toString` to return immutable strings which was not intended in
  this case.

* `ocean.net.HttpRequest.getUint(T)(cstring, ref T, out bool)`

  Deprecated in favor of `ocean.net.HttpRequest.getUnsigned(T)(cstring, ref T, out bool)`

* `ocean.net.HttpRequest.getUint(T)(cstring, ref T)`

  Deprecated in favor of `ocean.net.HttpRequest.getUnsigned(T)(cstring, ref T)`

New Features
============

* `util.container.map.model.BucketElementMallocAllocator`

  Added a new allocator (previously lived in alligator) which allocates map
  elements using `malloc()` and recycles them using `free()`.

* `util.container.map.model.IAllocator`

  Added a new `memoryUsed()` method which tracks the amount of memory allocated
  by the allocator.

* `util.container.map.model.*Allocators`

  Added helper functions to create an allocator instance which suitable to be
  used with a given map type.

* `util.container.map.Map`

  Added an overloaded constructor to the `StandardKeyHashingMap` class which
  allows usage of a custom allocator instead of the default one.

* `ocean.io.select.client.Scheduler`

  A new method, `clear()`, has been added, which unregisters all pending events.

* `ocean.util.app.ext.TimerExt`

  Application extension for handling user-defined timed or repeating events.

* `ocean.math.IncrementalAverage`

  Added new methods `variance()` and `stdDeviation()` to incrementally compute
  the variance and standard deviation respectively.

* `ocean.io.digest.Fnv1`

  A new method Fnv1Generic.combined was added that allows the easy creation of a hash
  from several input variables.

* `ocean.math.Range`

  The static `opCall` method to create initialised `Range` instances now
  correctly handles constructing empty ranges.
