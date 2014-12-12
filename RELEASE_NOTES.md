Dependencies
============

Dependency | Version
-----------|---------
tango      | v1.1
dmd1       | v1.076.s2

Migration Instructions
======================

* `ocean.util.config.ConfigParser`

  The return value of the `getList` method has been fixed. It used to
  incorrectly return true/false, but now returns a dynamic array.


Deprecations
============

* `ocean.text.convert.Layout`

  The `print` and `vprint` methods from this module are now deprecated in favour
  of the methods `format` and `vformat` respectively in the
  `tango.text.convert.Layout` module. Applications using either
  `Layout!().print()` or `Layout!(char).print()` need to update to use the
  methods from tango instead.


New Features
============
