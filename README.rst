

Migration Instructions
======================


master
======

``ocean.io.serialize.StructDumper``
  This class is no longer a template, the ``opCall()`` and ``dump()`` methods
  are templates instead. So you'll need to update both the instantiation place
  to remove the template parameter.  Normally the call site for those methods
  don't need to be updated if the template parameter can be correctly inferred.

  This way you can reuse a single instance of this class to dump all kinds of
  different objects.

  Note that the new ``BufferedStructDumper`` is the direct equivalent of the old
  ``StructDumper``. The new ``StructDumper`` is a simplified version without an
  internal buffer.


1.0 (2013-03-12)
================

* First stable branch

