Dependencies
============

Dependency | Version
-----------|---------
tango      | v1.3.x

Migration Instructions
======================

* `ocean.io.model.ISuspendableThrottler`

  `ISuspendableThrottler` now contains the method `removeSuspendable` to remove an
  `ISuspendable` from registered suspendables.

* `ocean.sys.CpuAffinity`

  - `CpuAffinity.set()` now throws `ErrnoException` on failure. It used to
    return `false` before; the return type is now `void`.

* `ocean.io.select.protocol.fiber.FiberSelectWriter`

  The following methods can now throw `IOError`:

    * `flush()`
    * `cork(bool)` (the setter method)

  Before these methods didn't throw. Now they do, especially if the socket file
  handle is invalid. A known case where this happens is if a server application
  attempts to enable cork for a client socket `FiberSelectWriter` object
  *before* handing the socket over to the writer object. This is wrong usage and
  a bug in the application code, which is not silently accepted any more.

Removed Symbols
---------------

Deprecations
============

New Features
============

* `ocean.util.container.MallocArray`

  A new module which contains collection of functions that aids in creating
  and manipulating malloc based arrays.

* `ocean.util.app.ext.TimerExt`

  Added `registerMicrosec()`, which accepts integer µs time values to allow
  using the precise time unit that is used by the underlying library calls.
