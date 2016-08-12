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

* `ocean.task.util.StreamProcessor`

  Constructor that expects `max_tasks`, `suspend_point` and `resume_point` has
  been deprecated in favor of one that takes a `ThrottlerConfig` struct.

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
