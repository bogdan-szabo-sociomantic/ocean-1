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

Deprecations
============

* `ocean.crypt`

  The whole package has been moved to `ocean.util.cipher` to adhere more to the
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
