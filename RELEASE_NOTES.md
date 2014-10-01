Dependencies
============

Dependency | Version
-----------|---------
tango      | v1.0.4
dmd1       | v1.076.s2

Migration Instructions
======================

Deprecations
============

New Features
============

* `ocean.io.device.DirectIO`
  `BufferedDirectReadFile` has a new protected method, `newFile()`, just like
  `BufferedDirectWriteFile`, so subclasses can change what `File` subclass to use.

