require 'formula'

class Python31 < Formula
  homepage 'http://www.python.org/'
  url 'http://www.python.org/ftp/python/3.1.5/Python-3.1.5.tar.bz2'
  sha1 '48f97250c0482d9672938f5781e66dbd19cd4374'

  option :universal
  option 'framework', 'Do a Framework build instead of a UNIX-style build'
  option 'static', 'Build static libraries'

  depends_on 'readline' => :recommended
  depends_on 'sqlite' => :recommended
  depends_on 'gdbm' => :recommended

  skip_clean ['bin', 'lib']

  # Was a Framework build requested?
  def build_framework?; build.include? 'framework'; end

  # Are we installed or installing as a Framework?
  def as_framework?
    (self.installed? and File.exists? prefix+"Frameworks/Python.framework") or build_framework?
  end

  def site_packages
    # The Cellar location of site-packages
    if as_framework?
      # If we're installed or installing as a Framework, then use that location.
      return prefix+"Frameworks/Python.framework/Versions/3.1/lib/python3.1/site-packages"
    else
      # Otherwise, use just the lib path.
      return lib+"python3.1/site-packages"
    end
  end

  def prefix_site_packages
    # The HOMEBREW_PREFIX location of site-packages
    HOMEBREW_PREFIX+"lib/python3.1/site-packages"
  end

  def install
    # --with-computed-gotos requires addressable labels in C;
    # both gcc and LLVM support this, so switch it on.
    args = ["--prefix=#{prefix}", "--with-computed-gotos"]

    # Otherwise the formula may attempt to use the python3 shim
    # even though python3 isn't installed yet
    ENV['PYTHON'] = 'python'

    if build.universal?
      args << "--enable-universalsdk=/" << "--with-universal-archs=intel"
    end

    if build_framework?
      args << "--enable-framework=#{prefix}/Frameworks"
    else
      args << "--enable-shared" unless build.include? 'static'
    end

    system "./configure", *args
    system "make"
    ENV.j1 # Installs must be serialized
    system "make install"

    # Add the Homebrew prefix path to site-packages via a .pth
    prefix_site_packages.mkpath
    (site_packages+"homebrew.pth").write prefix_site_packages
  end

  def caveats
    <<-EOS.undent
      The site-packages folder for this Python is:
        #{site_packages}

      We've added a "homebrew.pth" file to also include:
        #{prefix_site_packages}
    EOS
  end
end
