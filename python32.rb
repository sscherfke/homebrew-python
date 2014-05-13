require 'formula'

# Python3 is the new language standard, not just a new revision.
# It's somewhat incompatible to Python 2.x, therefore, the executable
# "python" will always point to the 2.x version which you can get by
# `brew install python`.

class TkCheck < Requirement
  def message; <<-EOS.undent
    Tk.framework was detected in /Library/Frameworks
    This can cause Python builds to fail. See:
      https://github.com/mxcl/homebrew/issues/11602
    EOS
  end

  def fatal?; false; end

  def satisfied?
    not File.exist? '/Library/Frameworks/Tk.framework'
  end
end

class Python32 < Formula
  homepage 'http://www.python.org/'
  url 'http://python.org/ftp/python/3.2.5/Python-3.2.5.tar.bz2'
  sha1 '6bd2714704995bc84fc9b8e3019205bf75d44969'
  VER='3.2'  # The <major>.<minor> is used so often.

  depends_on TkCheck
  depends_on 'pkg-config' => :build
  depends_on 'readline' => :recommended
  depends_on 'sqlite' => :recommended
  depends_on 'gdbm' => :recommended
  depends_on 'openssl' if build.include? 'with-brewed-openssl'

  option :universal
  option 'quicktest', 'Run `make quicktest` after the build'
  option 'with-brewed-openssl', "Use Homebrew's openSSL instead of the one from OS X"

  resource 'setuptools' do
    url 'https://pypi.python.org/packages/source/s/setuptools/setuptools-2.2.tar.gz'
    sha1 '547eff11ea46613e8a9ba5b12a89c1010ecc4e51'
  end

  resource 'pip' do
    url 'https://pypi.python.org/packages/source/p/pip/pip-1.5.4.tar.gz'
    sha1 '35ccb7430356186cf253615b70f8ee580610f734'
  end

  def site_packages_cellar
    prefix/"Frameworks/Python.framework/Versions/#{VER}/lib/python#{VER}/site-packages"
  end

  # The HOMEBREW_PREFIX location of site-packages.
  def site_packages
    HOMEBREW_PREFIX/"lib/python#{VER}/site-packages"
  end

  # Where distribute/pip will install executable scripts.
  def scripts_folder
    HOMEBREW_PREFIX/"share/python#{VER}"
  end

  def effective_lib
    prefix/"Frameworks/Python.framework/Versions/#{VER}/lib"
  end

  def install
    # Unset these so that installing pip and distribute puts them where we want
    # and not into some other Python the user has installed.
    ENV['PYTHONPATH'] = nil
    ENV['PYTHONHOME'] = nil

    # Otherwise the formula may attempt to use the python3 shim
    # even though python3 isn't installed yet
    ENV['PYTHON'] = 'python'

    args = %W[--prefix=#{prefix}
             --enable-ipv6
             --datarootdir=#{share}
             --datadir=#{share}
             --enable-framework=#{prefix}/Frameworks
           ]

    args << '--without-gcc' if ENV.compiler == :clang

    if build.universal?
      ENV.universal_binary
      args << "--enable-universalsdk" << "--with-universal-archs=intel"
    end

    if superenv?
      distutils_fix_superenv(args)
    else
      distutils_fix_stdenv
    end

    # Python does not need all of X11, these bundled Headers are enough
    ENV.append 'CPPFLAGS', "-I#{MacOS.sdk_path}/System/Library/Frameworks/Tk.framework/Versions/8.5/Headers" unless MacOS::CLT.installed?

    # Allow sqlite3 module to load extensions: http://docs.python.org/library/sqlite3.html#f1
    inreplace "setup.py", 'sqlite_defines.append(("SQLITE_OMIT_LOAD_EXTENSION", "1"))', 'pass'

    system "./configure", *args

    system "make"

    ENV.deparallelize # Installs must be serialized
    # Tell Python not to install into /Applications (default for framework builds)
    system "make", "install", "PYTHONAPPSDIR=#{prefix}"
    # Demos and Tools
    (HOMEBREW_PREFIX/"share/python#{VER}").mkpath
    system "make", "frameworkinstallextras", "PYTHONAPPSDIR=#{share}/python#{VER}"
    system "make", "quicktest" if build.include? "quicktest"

    # Any .app get a " 3" attached, so it does not conflict with python 2.x.
    Dir.glob(prefix/"*.app").each do |app|
      mv app, app.gsub(".app", " #{VER}.app")
    end

    # Post-install, fix up the site-packages and install-scripts folders
    # so that user-installed Python software survives minor updates, such
    # as going from 3.3.0 to 3.3.1:

    # Remove the site-packages that Python created in its Cellar.
    site_packages_cellar.rmtree
    # Create a site-packages in HOMEBREW_PREFIX/lib/python#{VER}/site-packages
    site_packages.mkpath
    # Symlink the prefix site-packages into the cellar.
    ln_s site_packages, site_packages_cellar

    # Teach python not to use things from /System
    # and tell it about the correct site-package dir because we moved it
    sitecustomize = site_packages_cellar/"sitecustomize.py"
    rm sitecustomize if File.exist? sitecustomize
    sitecustomize.write(sitecustomize_content)

    # Install distribute for python3 and assure there's no name clash
    # with what the python (2.x) formula installs.
    scripts_folder.mkpath
    setup_args = ["-s", "setup.py", "install", "--force", "--verbose", "--install-lib=#{site_packages_cellar}", "--install-scripts=#{bin}" ]

    resource('setuptools').stage { system "#{bin}/python", *setup_args }
    rm bin/'easy_install'
    resource('pip').stage { system "#{bin}/python", *setup_args }
    rm bin/'pip'

    # Tell distutils-based installers where to put scripts
    (prefix/"Frameworks/Python.framework/Versions/#{VER}/lib/python#{VER}/distutils/distutils.cfg").write <<-EOF.undent
      [install]
      install-scripts=#{scripts_folder}
      install-lib=#{site_packages}
    EOF

    unless MacOS::CLT.installed?
      makefile = prefix/"Frameworks/Python.framework/Versions/#{VER}/lib/python#{VER}/config-#{VER}m/Makefile"
      inreplace makefile do |s|
        s.gsub!(/^CC=.*$/, "CC=xcrun clang")
        s.gsub!(/^CXX=.*$/, "CXX=xcrun clang++")
        s.gsub!(/^AR=.*$/, "AR=xcrun ar")
        s.gsub!(/^RANLIB=.*$/, "RANLIB=xcrun ranlib")
      end
    end

  end

  def distutils_fix_superenv(args)
    # To allow certain Python bindings to find brewed software (and sqlite):
    cflags = "CFLAGS=-I#{HOMEBREW_PREFIX}/include -I#{Formula["sqlite"].opt_prefix}/include"
    ldflags = "LDFLAGS=-L#{HOMEBREW_PREFIX}/lib -L#{Formula["sqlite"].opt_prefix}/lib"
    unless MacOS::CLT.installed?
      # Help Python's build system (distribute/pip) to build things on Xcode-only systems
      # The setup.py looks at "-isysroot" to get the sysroot (and not at --sysroot)
      cflags += " -isysroot #{MacOS.sdk_path}"
      ldflags += " -isysroot #{MacOS.sdk_path}"
      # Same zlib.h-not-found-bug as in env :std (see below)
      args << "CPPFLAGS=-I#{MacOS.sdk_path}/usr/include"
      unless build.with? 'brewed-tk'
        cflags += " -I#{MacOS.sdk_path}/System/Library/Frameworks/Tk.framework/Versions/8.5/Headers"
      end
    end
    args << cflags
    args << ldflags
    # Avoid linking to libgcc http://code.activestate.com/lists/python-dev/112195/
    args << "MACOSX_DEPLOYMENT_TARGET=#{MacOS.version}"
    # We want our readline! This is just to outsmart the detection code,
    # superenv makes cc always find includes/libs!
    inreplace "setup.py",
              "do_readline = self.compiler.find_library_file(lib_dirs, 'readline')",
              "do_readline = '#{HOMEBREW_PREFIX}/opt/readline/lib/libhistory.dylib'"
  end

  def distutils_fix_stdenv()
    # Python scans all "-I" dirs but not "-isysroot", so we add
    # the needed includes with "-I" here to avoid this err:
    #     building dbm using ndbm
    #     error: /usr/include/zlib.h: No such file or directory
    ENV.append 'CPPFLAGS', "-I#{MacOS.sdk_path}/usr/include" unless MacOS::CLT.installed?

    # Don't use optimizations other than "-Os" here, because Python's distutils
    # remembers (hint: `python3-config --cflags`) and reuses them for C
    # extensions which can break software (such as scipy 0.11 fails when
    # "-msse4" is present.)
    ENV.minimal_optimization

    # We need to enable warnings because the configure.in uses -Werror to detect
    # "whether gcc supports ParseTuple" (https://github.com/mxcl/homebrew/issues/12194)
    ENV.enable_warnings
    if ENV.compiler == :clang
      # http://docs.python.org/devguide/setup.html#id8 suggests to disable some Warnings.
      ENV.append_to_cflags '-Wno-unused-value'
      ENV.append_to_cflags '-Wno-empty-body'
      ENV.append_to_cflags '-Qunused-arguments'
    end
  end

  def sitecustomize_content
    <<-EOF.undent
      # This file is created by `brew install python#{VER}` and is executed on each
      # python#{VER} startup. Don't print from here, or else universe will collapse.
      import sys
      import site

      # Only do fix 1 and 2, if the currently run python is a brewed one.
      if sys.executable.startswith('#{HOMEBREW_PREFIX}'):
          # Fix 1)
          #   A setuptools.pth and/or easy-install.pth sitting either in
          #   /Library/Python/#{VER}/site-packages or in
          #   ~/Library/Python/#{VER}/site-packages can inject the
          #   /System's Python site-packages.
          #   See: https://github.com/mxcl/homebrew/issues/14712
          sys.path = [ p for p in sys.path if not p.startswith('/System') ]

          # Fix 2)
          #   Remove brewed Python's hard-coded site-packages
          sys.path.remove('#{site_packages_cellar}')

      # Fix 3)
      #   For all Pythons: Tell about homebrew's site-packages location.
      #   This is needed for Python to parse *.pth files.
      site.addsitedir('#{site_packages}')
    EOF
  end

  def caveats
    text = <<-EOS.undent
      Homebrew's Python3 framework
        #{prefix}/Frameworks/Python.framework

      Setuptools and Pip have been installed. To update them
        pip-#{VER} install --upgrade setuptools
        pip-#{VER} install --upgrade pip

      To symlink "Idle #{VER}" and the "Python Launcher #{VER}" to ~/Applications
        `brew linkapps`

      You can install Python packages with
        `pip-#{VER} install <your_favorite_package>`

      They will install into the site-package directory
        #{site_packages}
      Executable python scripts will be put in:
        #{scripts_folder}
      so you may want to put "#{scripts_folder}" in your PATH, too.

      See: https://github.com/mxcl/homebrew/wiki/Homebrew-and-Python
    EOS

    # Tk warning only for 10.6
    tk_caveats = <<-EOS.undent

      Apple's Tcl/Tk is not recommended for use with Python on Mac OS X 10.6.
      For more information see: http://www.python.org/download/mac/tcltk/
    EOS

    text += tk_caveats unless MacOS.version >= :lion
    return text
  end

  test do
    # Check if sqlite is ok, because we build with --enable-loadable-sqlite-extensions
    # and it can occur that building sqlite silently fails if OSX's sqlite is used.
    system "#{bin}/python#{VER}", "-c", "import sqlite3"
    # Check if some other modules import. Then the linked libs are working.
    system "#{bin}/python#{VER}", "-c", "import tkinter"
  end
end
