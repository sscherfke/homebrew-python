require 'formula'

class Python24 < Formula
  homepage 'http://www.python.org/download/releases/2.4.6/'
  url 'http://www.python.org/ftp/python/2.4.6/Python-2.4.6.tgz'
  sha1 '4443e7646d622d35942f4e2c3342f251829915eb'

  depends_on 'gdbm' => :recommended
  depends_on 'readline' => :recommended

  # Skip binaries so modules will load;
  # skip lib because it is mostly Python files
  skip_clean ['bin', 'lib']

  # Fixed to compile on Lion by reusing a patch from the Plone guys.
  def patches
    {:p0 => %W[
      https://raw.github.com/collective/buildout.python/46f883ddaab4be778e87c9dcd23ec3446799dd04/src/python-2.4-darwin-10.6.patch
    ]}
  end

  def prefix_site_packages
    # The HOMEBREW_PREFIX location of site-packages
    HOMEBREW_PREFIX + "lib/python2.4/site-packages"
  end

  def install
    # The system readline is broken (bus error), and the formula is keg_only.
    # It seems presumptuous to `brew link readline`. So:
    ENV['CC'] = ["gcc", "-I#{Formula["readline"].prefix}/include",
                 "-L#{Formula["readline"].prefix}/lib"].join(" ")

    system "./configure", "--prefix=#{prefix}", "--disable-tk",
      "MACOSX_DEPLOYMENT_TARGET=#{MacOS.version}", "--enable-ipv6",
      "--enable-shared"
    ENV.j1
    system "/usr/bin/make"
    # no man pages; only install 'python2.4' binary, not 'python'
    system "make altbininstall"
    system "make libinstall"
    system "make inclinstall"
    system "make libainstall"
    system "make sharedinstall"
    system "make oldsharedinstall"
    # Add the Homebrew prefix path to site-packages via a .pth
    prefix_site_packages.mkpath
    (lib + "python2.4/site-packages/homebrew.pth").write prefix_site_packages
  end
end
