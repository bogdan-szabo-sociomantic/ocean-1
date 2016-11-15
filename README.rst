Description |BuildStatus|_
==========================

Ocean is a base, platform-dependant general purpose D library with all the
required core functionality that is missing from the language standard library
(Tango).  Part of Ocean is dedicated to fill some gaps in Tango or add some
improvements over the existing modules, but a big part of it contains very
low-level infrastructure needed to do real-time applications efficiently. That
is why memory allocation minimization is a key component in Ocean's design. For
the same reason a lot of non-portable constructions are used in Ocean.

Versioning
==========

Ocean uses Sociomantic's SemVer_ versioning model.

.. _SemVer: https://github.com/sociomantic/backend/blob/master/doc/structure/semver-user.rst

* Major branch development period: 6 months
* Maintained minor versions: 2 most recent
* Current default major branch: v1.x.x (until 2016-12-30)

Releases
========

`Latest stable release notes
<https://github.com/sociomantic/ocean/releases/latest>`_ | `Current, in
development, release notes
<https://github.com/sociomantic/ocean/tree/v1.x.x/relnotes>`_ | `All
releases <https://github.com/sociomantic/ocean/releases>`_

Releases are handled using `GitHub releases
<https://github.com/sociomantic/ocean/releases>`_. The release notes provided
there are usually structured in 3 sections, a **Migration Instructions**, which
are the mandatory steps that users have to do to update to a new version,
**Deprecated** which contains deprecated functions that are recommended not to
use but will not break any old code, and the **New Features** which are optional
new features available in the new version that users might find interesting.
Using them is optional, but encouraged.

Release notes should help developers to migrate from one version to another. The
changes listed are the steps you need to take to move from the previous version
to the one being listed. For example, all the steps described in version
**v1.5.x** are the steps required to move from **v1.4.x** to **v1.5.x**. If you
need to jump several versions at once, you should read all the steps from all
the intermediate versions. For example, to jump from **v1.2.x** to **v1.5.x**,
you need to first follow the steps in version **v1.3.x**, then the steps in
version **v1.4.x** and finally the steps in version **v1.5.x**.

.. |BuildStatus| image:: https://ci.sociomantic.com/buildStatus/icon?job=core-team/ocean
.. _BuildStatus: https://ci.sociomantic.com/job/core-team/job/ocean/
