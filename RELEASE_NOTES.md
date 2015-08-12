Dependencies
============

Dependency | Version
-----------|---------
tango      | v1.2.1

Migration Instructions
======================

* `ocean.util.container.map.utils.MapSerializer`

  If you change your key or value structs from non-versioned to versioned, you
  should first load the map before applying any change of the structs and dump
  the map again so it is saved in the new format. After that you can just add
  version-information as desired.

* `ocean.core.StructConverter`

  `structCopy()` was frequently mistaken for an equivalent of `deepCopy()`, however
  it doesn't do a true deep copy as it avoids copying memory when possible. To
  make this more clear the function was renamed to `structConvert()`.

* `ocean.io.serialize.SimpleSerializer`

  Upon EOF, `SimpleSerializer` now throws a new exception type, `EofException`.
  It previously threw `IOException`, making it impossible to distinguish between
  EOF and other I/O errors.

* `ocean.util.config.ClassFiller`

   Both `fill` overloads and `iterate` will now trigger an assertion failure
   if `null` is provided as the `config` parameter.
   The default parameter (which was `null`) has also been removed.

* `ocean.util.text.StringEncode`

  `IconvException.opCall` has been deprecated in favor of `enforce` or explicit
  constructor + throw.

* `ocean.io.select.event.TimerEvent`

  A new unittest in this module requires linking with `librt`. Any projects
  which import this module should add `-lrt` to the `LDFLAGS` override for
  unittest builds in their `Build.mak` file.

Removed Deprecated Modules
--------------------------

* `ocean.util.container.cache.PriorityCache`

  `droppingItem()` method has been replaced with `itemDropped()`. Also the
  notifier is now called after the item has already been removed from the
  cache. The refactored method passes the key as well as a reference to the
  dropped item as parameters. The default implementation of the method is
  to set the item to its init value.

* `ocean.crypt.HMAC`

  It was deprecated in 1.20.0

* `ocean.sys.SignalHandler`

  It was deprecated in 1.22.0

* `ocean.util.serialize.model.Version`

  It was deprecated int 1.22.0

Removed Deprecated Symbols
--------------------------

* `ocean.util.config.ConfigParser`

  `parse` has been taken out of the ConfigParser API. `parse` used to be an
  alias for the `parseFile` method, and has been deprecated since Oct 2014.

* `ocean.text.util.StringSearch`

   Two overload of `split` and `splitCollapse` which created arrays of slices
   and have been deprecated since late 2011 have been removed.

* `ocean.net.util.ParamsSet`

  Removed `*Uint` methods that where deprecated in 1.21.0

Removed Symbols
---------------

* `ocean.db.tokyocabinet.util.TokyoCabinetException`,
  `ocean.io.serialize.JsonStructDeserializer`,
  `ocean.io.serialize.StructSerializer`,
  `ocean.util.cipher.HMAC`,
  `ocean.util.config.ConfigParser`

   The following static opCall which trivially wrapped the exception constructor
   have been removed:
   - `ocean.db.tokyocabinet.util.TokyoCabinetException.TokyoCabinetException`
   - `ocean.db.tokyocabinet.util.TokyoCabinetException.TokyoCabinetException.Cursor`
   - `ocean.io.serialize.JsonStructDeserializer.JsonException`
   - `ocean.io.serialize.StructSerializer.SerializerException`
   - `ocean.util.cipher.HMAC.HMACException`
   - `ocean.util.config.ConfigParser.ConfigException`

   They can be replaced in a backward-compatible way by calling the constructor
   directly (prepend a `new`).

Deprecations
============

* `ocean.io.serialize.StructSerializer`

  The binary serialization facilities of this module have been deprecated. Any
  code which is still using this should be adjusted to use the new serializer in
  `ocean.util.serialize`. (The stream and plugin serialization facilities of
  `StructSerializer` remain unchanged.)

* `ocean.core.StructConverter.structCopy`

  The function has been renamed. See Migration Instructions.

* `ocean.util.Config`

   The module and it's globally-available `ConfigParser Config` member have been
   deprecated.  The app framework (`ConfigExt`, `ConfiguredApp` and `ConfiguredCliApp`)
   have been updated to instantiate it itself instead of relying on this global instance.
   This change is mostly transparent for applications, with the exception of the part
   mentioned in the Migrations Instructions.

* `ocean.util.container.queue.FlexibleRingQueue.serialize()/deserialize()`

  `serialize()` and `deserialize()` are deprecated and replaced with `save()`
   and `load()`.
   - `load()` validates the input data while `deserialize()` does not.
   - `deserialize()` causes the following memory allocation problems if the
     capacity of the queue is different to the one that produced the input data:
     1. If reading data produced with a lower capacity, assertions can fail and
        array bounds violated.
     2. If reading data produced with a higher capacity, the queue buffer size
        is set to the higher capacity. If a custom non-GC allocator is used, the
        buffer is allocated again by the GC.

* `ocean.util.container.queue.SimplifiedFlexibleRingQueue`

  Should be replaced with `ocean.util.container.queue.FlexibleRingQueue`.

* `ocean.math.Range`

  `opEquals` has been deprecated in favour of `isTessellatedBy`.  The latter
  function is exactly equivalent in its behaviour to the old `opEquals`, but
  its name reflects better the actual comparison that is being made.

  `subsetOf` and `supersetOf` have been deprecated in favour of `isSubsetOf`
  and `isSupersetOf` respectively.  The newer methods are not quite equivalent
  as they allow equal ranges to be considered as sub- or supersets of one
  another.


New Features
============

* `ocean.util.container.queue.FlexibleRingQueue`

  `push()` now accepts records of zero length. Note that such a record does
  occupy a few bytes of space in the queue. Also bear in mind that `pop()` will
  return an empty non-`null` slice when popping such a record.

* `ocean.util.container.map.utils.MapSerializer`

   `MapSerializer` now provides an easier path to update from maps using
   non-versioned keys or values to maps that start using a version for either.
   Additionally, the map now also always does a struct hash validation in case
   the versioning code was wrong.

* `ocean.core.Test`

  New test helper, `testNoAlloc`, which checks GC usage stats before and after
  calling given expression and ensures no allocations happen.

* `ocean.core.Exception`

   A new `DefaultExceptionCtor` mixin template has been introduced.
   Similar to `DefaultExceptionImpl`, you can mix it in to get the usual
   constructor for exceptions.

*  `ocean.util.container.queue.FlexibleRingQueue.save()/load()`

  These new methods use a compact and more flexible storage format:
  - `save()` only stores as much data as are currently in the queue while
    `serialize()` always stores as much data as the queue capacity.
  - The data produced by `save()` can be loaded by a queue of the same or
    higher capacity. In general a queue data string output by `save()` can be
    loaded by any queue whose capacity is at least the length of that data
    string. Note that a queue can still not load more saved data than its
    capacity, this needs still to be addressed.

    Note that the data format used by the new `save()` and `load()` methods is
    not compatible to the one used by the now deprecated `serialize()` and
    `deserialize()`.

* `ocean.io.model.ISuspendable`

   Abstract class for any processes that can be suspended/resumed.

  * `ocean.io.model.ISuspendableThrottler`

   Abstract class for creating classes that can suspend and resume
   groups of processes implementing the `ocean.io.model.ISuspendable` interface.
   The conditions for suspending/resuming are defined by the abstract methods
   of `suspend()`/`resume()`.

* `ocean.io.model.SuspendableThrottlerCount`

   A new counter based suspendable throttler has been added to suspend and
   resume `ISuspendable` processes. `SuspendableThrottlerCount` will suspend
   and resume registered `ISuspendable` objects based off internal counter
   (eg. number of pending items to be processed) that can be
   incremented/decremented via `add()`/`remove()`. When the counter
   reaches the suspend point `suspend()` is called on all processes. Once
   the internal counter reaches the resume point then `resume()` will be called
   on registered processes.

* `ocean.math.Range`

  An extensive amount of new functionality has been added to this module,
  including both new methods of the `Range` struct and external functions.

  * new methods of `Range!(T)`:

    * `contains` method that checks if a single `T` value falls within the
      `min`, `max` bounds of the current range

    * `isCoveredBy` method that checks whether the union of elements of a sorted
      array of `Range!(T)`s is a superset of the current range

    * `isSubsetOf` method that checks whether the range is a non-empty subset
      of some other `Range!(T)` instance

    * `isSupersetOf` method that checks whether some other `Range!(T)` instance
      is a non-empty subset of the current range

    * `isTessellatedBy` method that checks whether a sorted array of `Range!(T)`
      elements is contiguous and that its union is exactly equal to the current
      range.  (This can be in practice seen as a kind of "equivalence" condition
      between single ranges and arrays of ranges.)

    * `toString` (`UnitTest` version only) to help provide more informative
      unittest output

    * static `makeRange` factory method to construct a `Range!(T)` instance
      based on specified boundary conditions and min/max values.  Unlike
      `opCall`, this method will not throw or assert if given invalid input:
      instead it will merely return an empty range.

  * new external functions:

    * `extent` function that returns a single `Range!(T)` value whose `min`
      and `max` values reflect the smallest and largest `min` and `max` found
      among all the elements of a (sorted) array of `Range!(T)` elements

    * `hasGap` function that checks if a sorted array of `Range!(T)` elements
      has any gaps between individual ranges

    * `hasOverlap` function that checks if a sorted array of `Range!(T)`
      elements has any overlap between individual ranges

    * `isContiguous` function that checks if a sorted array of `Range!(T)`
      elements has neither gap nor overlap.  This is a more efficient version
      of the check `!hasGap(...) && !hasOverlap(...)`.

* `ocean.util.container.HashRangeMap`

  The `HashRangeMap` struct provides a specialized map between `Range!(hash_t)`
  keys and arbitrary values, in a data structure that is serializable using
  `ocean.util.serialize.contiguous`.

* `ocean.util.container.queue.NotifyingQueue`

  `NotifyingByteQueue` (and `NotifyingQueue`) now implement the
  `ISuspendable` interface from `ocean.io.model.ISuspendable`.

* `ocean.util.container.queue.NotifyingQueue`

  Added `isRegistered` to the `NotifyingByteQueue` class.
  This method checks whether the provided notifier is already registered.
  Note: This is an O(n) search, however it should not have a performance
  impact in most cases since the number of registered notifiers is typically
  very low.

