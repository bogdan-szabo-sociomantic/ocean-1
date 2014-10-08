Dependencies
============

Dependency | Version
-----------|---------
tango      | v1.0.4
dmd1       | v1.076.s2

Migration Instructions
======================

* `ocean.util.serialize.contiguous.Deserializer.copy`
  `copy` was moved from `Deserializer` module to new `Util` module. Update your
  imports unless you use `package_.d`

Deprecations
============

New Features
============

* `ocean.io.device.DirectIO`
  `BufferedDirectReadFile` has a new protected method, `newFile()`, just like
  `BufferedDirectWriteFile`, so subclasses can change what `File` subclass to use.

* `ocean.util.serialize.contiguous.Util`
  New module that contains utilities built on top of (de)serializer. New `copy`
  overload was added here that can copy any "normal" structure `S` to
  `Contiguous!(S)`
