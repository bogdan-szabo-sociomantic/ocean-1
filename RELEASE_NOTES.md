Dependencies
============

Dependency | Version
-----------|---------
makd       | v1.3.x
tango      | v1.3.x

Migration Instructions
======================

* `ocean.text.convert.Integer_tango`

  `format` and `formatter` are now templated on the integer type they get as an argument,
  allowing to properly format negative numbers into their non-decimal
  (binary, octal, hexadecimal) representation.
  In addition, passing an `ulong` value which is > `long.max` with format "d" will now
  be correctly formatted (before it resulted in a negative value and required "u" to be used).

* `ocean.util.serialize.model.VersionDecoratorMixins`

  `VersionHandlingException` has been changed to avoid allocating a
  new message any time a conversion fails.

* `ocean.transition`

  `enableStomping` function now can't be called on arrays of `immutable` or
  `const` elements. This may cause compilation errors but any code which
  is subject to it was triggerring undefined behaviour and must be fixed
  with uttermost importance.

Deprecations
============

* `ocean.util.cipher.gcrypt: MessageDigest, HMAC`

  `HMAC` has been moved to a separate module, `ocean.util.cipher.gcrypt.HMAC`.
  The `HMAC` class in `ocean.util.cipher.gcrypt.MessageDigest` is deprecated.

  `MessageDigest.hash()` and `HMAC.hash(void[][] ...)` are deprecated and
   replaced with `calculate(`ubyte[][] ...`)`.  This is to avoid an implicit
   cast from `void[][]` to `void[]` when calling the function, which causes a
   wrong hash result, and the error is hard to find.

* `ocean.io.select.client.EpollProcess.ProcessMonitor`

  All references to the ProcessMonitor class should be removed. It existed
  only as a workaround for a bug in EpollProcess, but is no longer required.

New Features
============

* `ocean.io.serialize.StringStructSerializer`

  Introduced an overload of the `StringStructSerializer` serializer
  which takes an array of known timestamp field names.
  If a field matches one of the names and implicitly converts to `ulong`,
  an ISO formatted string will be emitted in parentheses next to the value of
  the field (which is assumed to be a unix timestamp).

  Bugfix: Trailing spaces are no longer emitted for arrays with length zero.

* `ocean.util.cipher.gcrypt.AES`

  Added libgcrypt AES (Rijndael) algorithm with a 128 bit key.

* `ocean.util.config.ClassFiller`

  In the ClassIterator, a new `opApply()` function has been added to provide
  foreach iteration only over the names of the matching configuration
  categories.

* `ocean.task.util.StreamProcessor`

  Added getter method for the internal task pool.

* `ocean.net.collectd.{Collectd,Identifier,SocketReader}`

  A new package to interact with a collectd UnixSocket has been added.
  It currently contains 3 modules:

  - Collectd: Defines the `Collectd` class which is the main interface to interact
              with the socket. The interface is currently limited to sending data
              to Collectd via the `putval` method

  - Identifier: Defines the `Identifier` struct used to model collectd's identifier
                consisting of 5 fields defining a unique identifier.

  - SocketReader: Allocation-free rotating buffer used internally by the `Collectd` class
                  to interact with the socket.

  Those modules are not meant to be used directly; `StatsLog` presents a higher level
  user interface for application developers to use (see below).

* `ocean.util.app.ext.StatsExt` and `ocean.util.log.Stats`

  Support for directly writing to the collectd socket has been added. This support is
  an addition to the existing functionality, rather than a replacement: even when
  writing to collectd is activated, the usual stats log file will still be written.
  Collectd logging is enabled by setting the `socket_path`, `app_name`, and `app_instance`
  variables in the config file (all three are required). Once set, several other settings
  can be overriden (most likely, you will be interested in the `default_type`). Read the
  `StatsExt` module documentation and the configuration documentation in `StatsLog` for
  more information.

  Example stats config setting to write to collectd as well as a file:

  ```
  [Stats]
  socket_path = /var/run/collectd.socket
  app_name = MyApp
  app_instance = 1
  ```
