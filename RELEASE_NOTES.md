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

* `ocean.net.email.EmailSender`

  The method sendEmail has been changed to have contain an optional
  Reply To header and this change breaks the API. Since the whole
  module is an hack and only one Application is using all the optional
  parameters this is the easiest solution.

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
