

Migration Instructions
======================


master
======

``ocean.io.serialize.StructDumper``
  This class is not longer a template, the ``opCall()`` and ``dump()`` methods
  are templates instead. So you'll need to update both the instantiation place
  to remove the template parameter.  Normally the call site for those methods
  don't need to be updated if the template parameter can be correctly inferred.

  This way you can reuse a single instance of this class to dump all kind of
  different objects.


1.0 (2013-03-12)
================

* First stable branch

