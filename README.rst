

Migration Instructions
======================

These instructions should help developers to migrate from one version to
another. The changes listed here are the steps you need to take to move from
the previous version to the one being listed. For example, all the steps
described in version **1.5** are the steps required to move from **1.8** to
**1.5**.

If you need to jump several versions at once, you should read all the steps
from all the involved versions. For example, to jump from **1.2** to **1.5**,
you need to first follow the steps in version **1.3**, then the steps in
version **1.4** and finally the steps in version **1.5**.


master
======

``ocean.io.serialize.StructDumper``
  This class is no longer a template, the ``opCall()`` and ``dump()`` methods
  are templates instead. This way you can reuse a single instance of this
  class to dump all kinds of different objects.

  To upgrade you have to remove the template parameter when instantiating the
  class (or referencing the type). Normally the call site for the now templated
  methods don't need to be updated if the template parameter can be correctly
  inferred.

  Note that the new ``BufferedStructDumper`` is the direct equivalent of the old
  ``StructDumper``. The new ``StructDumper`` is a simplified version without an
  internal buffer.


1.0 (2013-03-12)
================

* First stable branch

