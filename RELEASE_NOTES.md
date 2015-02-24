Dependencies
============

Dependency | Version
-----------|---------
tango      | v1.1
dmd1       | v1.076.s2

Migration Instructions
======================

* `ocean.net.server.connection.IConnectionHandler`,
  `ocean.net.server.connection.IFiberConnectionHandler`

  The error delegate (which is optionally passed to the constructor) has changed
  type from `void delegate ( Exception exception, Event event )` to `void
  delegate ( Exception exception, Event event, IConnectionHandlerInfo )`.

* `ocean.core.ObjectPool`
  `ocean.time.UnixTime`
  `ocean.io.serialize.TraceStructSerializer`
  `ocean.util.Unittest`
  `ocean.util.app.UnittestedApp`
  `ocean.util.app.ext.UnittestExt`
  `ocean.crypt.misc.Bitwise`
  `ocean.crypt.misc.ByteConverter`
  `ocean.util.container.ebtree.c.ebnode`

  These deprecated modules have been completely removed. Check migration
  instructions from initial deprecation of relevant module if your app
  still uses it.

Deprecations
============

* `ocean.crypt.HMAC`

  This module has been moved to `ocean.util.cipher` to adhere more to the
  tango structure

New Features
============

* `ocean.db.tokyocabinet.TokyoCabinetM`

  * A new `get()` method has been added which allows a record to be got via a
    delegate, rather than copying into a buffer. This can be useful in situations
    where the user doesn't need to store the value.

  * A new non-interruptible `opApply` iterator has been added which implements a
    much more efficient form of iteration over the in-memory database. This can,
    obviously, only be used in situations where you are sure that only a single
    iteration is underway at any one time.

* `ocean.core.TypeConvert`

  This new module currently contains functions to perform generic casts and
  object down-casts, with (in comparison to standard casts) the added safety of
  checking that the thing being cast from is of the correct type. Using these
  functions helps prevent refactoring errors -- a standard cast will, for
  example, happily convert any pointer to an object which, if the user intended
  a down-cast, can cause errors at run-time.

* `ocean.util.container.cache.PriorityCache`

  Keeps track of a limited number of items according to their priority, when a
  new item is added and the cache is full then the item with the least priority
  is dropped.
  This class is experimental for this release. However users who use the current
  cache classes are encouraged to switch to the new cahce classes added in this
  release and report any found bugs. The current cache classes will be
  deprecated in the next release in favor of the new ones add in this release.
