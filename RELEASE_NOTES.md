Dependencies
============

Dependency | Version
-----------|---------
tango      | v1.3.x

Migration Instructions
======================

`ocean.util.container.queue.NotifyingQueue`

  A new overload of the `NotifyingQueue.pop` method has been introduced which
  takes a `ContigousBuffer!(Struct)` and a `ubyte[]` buffer when
  `NotifyingQueue` is instantiated with a struct type,

  For `NotifyingQueue` instantiated with a struct type, the old `pop()`
  method only taking a byte buffer has been deprecated.

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

* `script`

  The (outdated) Makd copy which lived under `script/` has been removed.


* `tango.sys.consts.fcntl`

  This module was deprecated since inclusion in ocean (1.25), as it was deprecated
  by tango 1.3. It is believed to be unused.

* `tango.sys.consts.socket`

  This module was deprecated since inclusion in ocean (1.25), as it was deprecated
  by tango 1.3. It is believed to be unused.

* `ocean.core.DeepCopy`

  This module was deprecated in ocean 1.24


Deprecations
============

New Features
============


