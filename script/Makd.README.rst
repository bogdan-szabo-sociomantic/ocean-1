====
Makd
====

Makd (pronounced "maked") is a GNU Make library/framework based on Makeit_,
adapted for D and in particular to Sociomantic's projects layout.

It combines the power of Make and rdmd to provide a lot of free functionality,
like implicit rules to compile binaries (only when necessary), tracking if any
of the source files changed, it improves considerably Make's output, it provides
a default test target that runs unittests, it detects if you change the
compilation flags and recompile if necessary, etc.



Files / Quickstart
==================

Top-level Makefile
------------------
To get started you need to have ocean as a submodule and create a top-level
makefile for your project (or convert the old one).

A typical Top-level ``Makefile`` should look like this::

        # Include the top-level makefile
        include submodules/ocean/script/Makd.mak

        # Default goal for building this directory
        .DEFAULT_GOAL := all

Assuming your ocean installation is in ``submodules/ocean``.  ``DEFAULT_GOAL``
is a special GNU Make variable to tell which target should be built when you
just run ``make`` without arguments. This is optional, if you don't set it, it
will default to ``all`` anyway, but if you set it, make sure you define it
**after** including ``Makd.mak``, order is important.

This file should be written only once and never touched again. But in your
project you might have more than one Makefile, for example you could have one in
your ``src`` directory and another one in your ``test`` directory, so you can do
``make`` in ``src`` without specifying ``-C ..``. Also, probably your
``DEFAULT_GOAL`` in the ``src/Makefile`` will be ``all`` while the one in
``test/Makefile`` can be ``test`` instead.


Config.mak
----------
Makd has a lot of configuration variables available. This file lives in the
top-level directory of the project and serves as a global configuration point.
There is only one ``Config.mak`` per project, so the configuration defined here
should make sense for all the ``Makefile``\s defined across the project. For
example you could redefine the colors used here, or the default DMD binary to
use. This is why this file, when present, should be always added to the version
control system. But normally you shouldn't need to create this file.

This file (and Config.local.mak_) should only define variables, as it's parsed
before any other variables or functions are defined. All the predefined variable
and functions available in Build.mak_ are not available here, except for
``$F``, ``$T`` and ``$R``, so use with care (see `Predefined variables`_ for
details).


Config.local.mak
----------------
This is a local version of the Config.mak_, so users can customize the build
system to their taste. Here is where you usually should define which Flavor_ to
compile by default, or which colors to use, or the path to a non-conventional
compiler location. This file should never be added to the version control
system.

This file is loaded **after** Config.mak_ so it overrides its values.


Build.mak
---------
This is the file where you define what your ``Makefile`` will actually do. Makd
does a lot for you, so this file is usually very terse. To define a binary to
compile, all you need to write in your ``Build.mak`` is this::

        $B/someapp: $C/src/main/someapp.d

That's it, this is the bare minimum you need. With this you can now write ``make
$PWD/build/devel/bin/someapp`` and you should get your binary there. ``$B`` is
a special variable holding the path where your binaries will be stored, and
``$C`` is a special variable storing the current path (the path where the
current ``Build.mak`` is, not the directory where ``make`` was invoked). Both
are absolute paths, to enable Makd to support building the project from
different locations (to make this work you should refer to all the project files
using this ``$C/`` *prefix* when you refer to the current directory of your
``Build.mak``). Why ``build/devel/bin`` will be explained later in the next
section.

Usually you want a shortcut to type less, so you might want to add::

        .PHONY: someapp
        someapp: $B/someapp

Now you can simply write ``make someapp`` to build it. Simple.

But maybe you want to type just ``make``. Since the ``DEFAULT_GOAL`` defined in
your ``Makefile`` is ``all``, you can use the special ``all`` variable to add
targets to build when is called::

        all += someapp

Now you can simply write ``make`` and you'll get your program built.

Putting it all together, your file should look like::

        .PHONY: someapp
        someapp: $B/someapp
        $B/someapp: $C/src/main/someapp.d
        all += someapp


The build directory
-------------------
Everything built by Makd is left in the ``build`` directory (or the directory
specified in ``BUILD_DIR_NAME`` variable if you defined it). In the build
directory you can find these other directories and files:

``<flavor>``
        Makd support Flavors_ (also called variants), by default flags are
        provided for the *devel* and the *production* flavors. All the symbols
        produced by the *devel* variant (the default) for example, will live in
        the ``devel`` subdirectory in the build directory.

``last``
        This is a symbolic link to the latest flavor that has been built. Is
        useful to use by script, where you do ``make`` but you don't know the
        name of the default flavor. Then you can just access to ``build/last``.

``doc``
        Generated documentation is put in this directory. Flavors shouldn't
        affect how the documentation is built, so there is only one ``doc``
        directory.

Each flavor directory have a set of files and directories of its own:

``bin``
        This is where the generated binaries are left.

``tmp``
        This is where object files, dependencies files and any other temporary
        file is left. Usually after a build all the contents of this directory
        is trash and only works as a cache. If you remove this directory a new
        build will be triggered next time you run make though, even if nothing
        changed. The project directory structure is replicated inside this
        directory, except for the directories specified by the
        ``BUILD_DIR_EXCLUDE`` variable (by default the build directory itself,
        the ``.git`` directory and the submodule directories).

``build-d-flags``
        A signature file to keep track of building flags changes.



Usage
=====

Building a project
------------------
Once you have the basic setup done, you can already enjoy a lot of small cool
features. For example you get a nice, terse and colorful output, for example::

        mkversion src/Version.d
        rdmd1 build/devel/bin/someapp

If there are any errors, messages will appear in red so they are easier to spot.

If you like the good old make verbose output, just use ``make V=1`` and you'll
get everything. If you don't like colors, just use ``make COLOR=``. Makd also
honours Make options ``--silent``, ``--quiet`` and ``-s``. So if you want to
avoid all output, just use ``make -s`` as usual.

All these variables can be configured in your Config.local.mak_ if you want to
always have it verbose or whatever.

If you want to force a build there is also the not-so-known ``make -B``, there
is no need to use the built-in ``make clean`` target and destroy all your cache
(with all the other Flavors_ you compiled in the past).

By default the ``devel`` flavor is compiled, but you can compile the
``production`` flavor by using ``make F=production``.

Also, if you have several cores, use ``make -j2`` and enjoy of Make's
parallelism for free! (this will use 2 cores, you can use ``-j3`` for 3 and so
on).

If you want to build as much as possible without stopping, you can also use
``make -k`` (for ``--keep-going``) so Make doesn't stop on the first error.
This is particularly useful for Testing_, if you want to find out how many tests
are broken without fixing everything first.

Finally, if you want to speed things up a little bit, you can use ``make -r``,
which suppress the many Make predefined rules, which we don't use and sometime
makes Make evaluate more options than needed.

Of course you can combine many Makd and Make options, and specify more than one
target, for example::

        make -Brj4 F=production V=1 COLOR= all test


Predefined targets
------------------
So, we already shown you can use a couple of built-in predefined targets. The
whole set of predefined targets are:

* ``all``
* ``clean``
* ``test``
* ``unittest``
* ``doc``
* ``install``
* ``uninstall``

Not all of them will be useful out of the box, you need to assign other targets
to them to be useful. In this category are: ``all``, ``doc``, ``install`` and
``uninstall``. For ``all`` we already saw how to feed it, just add targets to
the predefined variable with the same name (``all += sometarget``). All those
special target behaves the same. But for now we'll probably won't use the
(``un``)\ ``install`` targets and in a near future a built-in ``doc`` target
will be provided, so you'll probably won't use that one for now either.

The built-in ``unittest`` target will compile and run the unittests in every
``.d`` file found in the ``src`` directory. Each module will be run
independently. The ``test`` also is fed by the ``test`` variable, but the
``unittest`` target is already added (``test += unittest`` is done by Makd).

The ``clean`` target just removes `The build directory`_ recursively. Just
remember to put all your generated files there and the clean target will always
work ;). If you can't do that (because you generated a source file for example),
you can use the special variable ``clean`` too (``clean += src/trash.d
src/garbage.d`` for example).


Predefined variables
--------------------
There are a lot of predefined variables provided by Makd, we've already seen
quite a few important ones (``F``, ``COLOR``, ``V`` for example).

Some of these variables are meant to be overridden and some are mean to be just
used (read-only), otherwise the library could break. Here we list a lot of them,
but always check the source ``Makd.mak`` if you want to know them all!

The standard Make variable ``LDFLAGS`` have a special treatment when used with
``dmd``/``rdmd``: the ``-L`` is automatically prepended, so if you need to
specify libraries to link to, just use ``-lname``, not ``-L-lname`` (same with
any other linker flag).

Variables you might want to override
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
* The special target variables ``all``, ``test``, ``doc`` and ``install``.
* Color handling variables (``COLOR``\ * variables, please look at the Makd.mak
  source for details).
* ``F`` to change the default Flavor to build.
* ``V`` to change the default verboseness.
* ``BUILD_DIR_NAME`` and ``BUILD_DIR_EXCLUDE``, but usually you shouldn't.
* Program location variables: ``DC`` is the D compiler to use, you can build
  your project with a different DMD by using ``make
  DC=/usr/bin/experimental-dmd`` for example. Same for ``RDMD``.
* ``D_GC`` to change the default (cdgc) GC implementation to use.
* Less likely you might want to override the ``DFLAGS`` or ``RDMDFLAGS``, but
  usually there are better methods to do that instead.

Some of this variables are typically overridden in the Config.mak_ file, others
in the Build.mak_ file, others in the Config.local.mak_ or directly in the
command line (like the style stuff).

Read-only variables
~~~~~~~~~~~~~~~~~~~
Probably the most important read-only variables are the ones related to
generated objects locations:

* ``T`` is the project's top-level directory (retrieved from git).
* ``R`` is the current directory relatively to ``$T``.
* ``C`` is the directory where the current Build.mak_ is (which might not be the
  same as the Make predefined variable ``CURDIR``). You should always use this
  variable to refer to local project files.
* ``G`` is the base generated files directory, taking into account the flavor
  (for example ``build/devel``).
* ``O`` is the objects/temporary directory (for example ``build/devel/tmp``).
* ``B`` is the generated binaries directory (for example ``build/devel/bin``).
* ``D`` is the generated documentation directory (for example ``build/doc``).

All these variables except for ``R`` are **absolute** paths. This is to work
properly when run in different directories. You should take that into account.


Predefined functions
--------------------
There are a few useful predefined functions you might want to know about. Only
the most important (the ones you are most likely to use) are mentioned here,
once again, please refer to the Makd.mak source if you want to see them all.

exec
~~~~
Probably the most important is ``exec``. This function takes care of the pretty
output and verboseness. Each time you write a custom rule (hopefully you won't
need to do this often), you should probably use it. Here is the function
*signature*::

        $(call exec,command[,pretty_target[,pretty_command]])

``command`` is the command to execute, ``pretty_target`` is the name that will
be printed as the target that's being build (by default is ``$@``, i.e. the
actual target being built), and ``pretty_command`` is the string that will be
print as the command (by default the first word in ``command``).

Here is an example rule::

        touch-file:
                $(call exec,touch -m $@)

This will print::

        touch touch-file

When built. And will print ``touch -m touch-file`` if ``V=1`` is used, as
expected.

check_deb
~~~~~~~~~
This is a very simple function that just checks a certain Debian package is
installed. The *signature* is::

        $(call check_deb,package_name,required_version[,compare_op])

``package_name`` is, of course, the name of the package to check.
``required_version`` is the version number we require to build the project and
``compare_op`` is the comparison operator it should be used by the check (by
default is >=, but it can be any of <,<=,=,>=,>).

You can use this as the first command to run for a target action, for example::

        myprogram: some-source.d
        	$(call check_deb,dstep,0.0.1-sociomantic1)
        	rdmd --build --whatever.

If you need to share it for multiple targets you can just make a simple alias
with a lazy variable::

        check_dstep = $(call check_deb,dstep,0.0.1-sociomantic1)

        myprogram: some-source.d
        	$(check_dstep)
        	rdmd --build --whatever.

V
~~~
OK, this is not really a function, but you might use it in a way that can be
closer to a function than a variable. When we are in verbose mode, ``V`` is
empty and when we are not in verbose mode is set to ``@``. The effect is you
only get some Make output if we are not in verbose mode.

For example, this::

        test:
                $Vecho test

If called via ``make test`` will produce::

        test

While if called via ``make V=1 test``, it will produce::

        echo test
        test

This is only useful for commands you normally don't want to print, but you want
to be friendly to the user and show the command if verbose mode is used.
Normally you should always use ``$V`` instead of ``@``.

Yes, is a bit confusing that ``$V`` internally becomes empty when you use
``V=1``, but when you use it is very natural :)


Flavors
-------
Flavors are just different ways to compile one project using different flags. By
default the ``devel`` and ``production`` flavors are defined. The `The build
directory`_ stores one subdirectory for each flavor so you can compile one after
the other without mixing objects compiled for one with the other and your cache
doesn't get destroyed by a ``make clean``.

To change variables based on the flavor (or define new flavors), usually the
`Config.mak`_ is the place, and you can use normal Make constructs, for
example::

        ifeq ($F,devel)
        override DFLAGS += -debug=ProjectDebug
        endif

        ifeq ($F,production)
        override DFLAGS += -version=SuperOptimized
        endif

Usually the ``override`` option is needed, if you want to still add these
special flags even if the user passes a ``DFLAGS=-flag`` to Make.

To define a *new* flavor just use a new name, no other special treatment is
needed.

To compile the project using a particular flavor, just pass the ``F`` variable
to make, for example::

        make F=production

If you need to define more flavors, you can do so by defining the
``$(VALID_FLAVORS)`` variable in your ``Config.mak``, for example::

        VALID_FLAVORS := devel production profiling


Target specific flags
---------------------
There is a not-so-known Make feature that makes it very easy to override
variables for a particular target, and usually that's the best way to pass
specific variables to a particular target.

For example, you need to link one binary to a particular library but not the
others, then just do::

        $B/prog-with-lib: override LDFLAGS += -lthelib
        $B/prog-with-lib: $C/src/progwithlibs.d

        $B/prog: $C/src/prog.d

Then ``LDFLAGS`` will only include ``-lthelib`` when the target
``$B/prog-with-lib`` is made, but not others. One catch about this is this
variable override is propagated, so if your target needs to build a prerequisite
first, the building of the prerequisite will also see the modified variable. If
you want to avoid this, Makd also expands the special variable
``$($@.EXTRA_FLAGS)``. That is ``$(<name of the target>.EXTRA_FLAGS)`` (yes,
Make support recursive expansion of variables :D), for example::

        $B/prog-with-lib.EXTRA_FLAGS := -lthelib
        $B/prog: $C/src/prog.d

Will have a similar effect, but the variable expansion will only work for this
particular target. This is a corner case and hopefully you won't need to use it.


Testing
-------
Makd support testing generally by the special variable ``$(test)`` and the
``test`` target, and adds automatic *unittest* support on top of that, that can
be ran by using the predefined ``unittest`` target. The ``unittest`` target is
automatically added to ``$(test)``, so when you run ``make test`` the unittests
are run.

If you have a test script, you can easily add the target to run that script to
``$(test)`` too. For example::

        .PHONY: supertest
        supertest:
                ./super-test.sh
        test += supertest

Then when you run ``make test`` both the *unittests* and your test will run.

Skipping modules
~~~~~~~~~~~~~~~~

If you want to skip some module from the *unittest* run, you can add files to
the special variable ``$(TEST_FILTER_OUT)``. This should be done in the
Build.mak_ file normally. The contents of this variable are used as arguments
to the Make ``$(filter-out)`` function. This means you can use a single ``%``
as a wildcard, useful for example if you want to skip a whole package.

Examples::

        TEST_FILTER_OUT += \
                $C/src/brokenmodule.d \
                $C/src/brokenpackage/%

Always use ``+=``, there might be other predefined modules to skip.

Adding specific flags
~~~~~~~~~~~~~~~~~~~~~

Some modules might need special flags for the unittest to compile it properly that
aren't part of the main flags, e.g. when it was overriden for specific targets.

For those cases you can add unittest specific flags, just remember the target
is ``$O/unittests``.

Example::

        $O/unittests: override LDFLAGS += -lglib-2.0

Links the unittests to the glib-2.0 library.

Re-running unittests manually
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Once you built and ran the unittests once, if you want, for some reason, repeat
the tests, you can just run the generated ``unittests`` program. A reason to
run it again could be to use different command-line options (it accepts a few,
try ``build/last/unittests -h`` for help).

For example, if you want to re-run the tests, but without stopping on the first
failure, use::

        build/last/unittests -k

This option is used automatically if you run ``make -k``.

Remember to re-run ``make`` if you change any sources, the ``unittests``
program needs to be re-compiled in that case!



.. _Makeit: http://git.llucax.com.ar/w/software/makeit.git

