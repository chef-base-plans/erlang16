pkg_name=erlang16
pkg_origin=core
pkg_version="R16B03-1"
pkg_description="A programming language for massively scalable soft real-time systems."
pkg_upstream_url="http://www.erlang.org/"
pkg_dirname=otp_src_${pkg_version}
pkg_license=('Apache-2.0')
pkg_maintainer="The Habitat Maintainers <humans@habitat.sh>"
pkg_source=http://www.erlang.org/download/otp_src_${pkg_version}.tar.gz
pkg_filename=otp_src_${pkg_version}.tar.gz
pkg_shasum=17ce53459bc5ceb34fc2da412e15ac8c23835a15fbd84e62c8d1852704747ee7
pkg_deps=(core/glibc core/zlib core/ncurses core/openssl core/sed)
pkg_build_deps=(core/coreutils core/gcc core/make core/openssl core/perl core/m4 core/patch)
pkg_bin_dirs=(bin)
pkg_include_dirs=(include)
pkg_lib_dirs=(lib)

do_prepare() {
  # The `/bin/pwd` path is hardcoded, so we'll add a symlink if needed.
  if [[ ! -r /bin/pwd ]]; then
    ln -sv "$(pkg_path_for coreutils)/bin/pwd" /bin/pwd
    _clean_pwd=true
  fi

  if [[ ! -r /bin/rm ]]; then
    ln -sv "$(pkg_path_for coreutils)/bin/rm" /bin/rm
    _clean_rm=true
  fi

  # This fixes:
  #
  # checking for tgetent in -lncurses... no
  # checking for tgetent in -lcurses... no
  # checking for tgetent in -ltermcap... no
  # checking for tgetent in -ltermlib... no
  # configure: error: No curses library functions found
  # configure: error: /bin/sh '/var/tmp/paludis/dev-lang-erlang-16/work/otp_src_R16B/erts/configure' failed for erts
  #
  # Thanks to https://bugs.gentoo.org/475800#c5
  patch erts/configure $PLAN_CONTEXT/patches/000-tinfo.patch
}

do_build() {
  ./configure --prefix="${pkg_prefix}" \
              --enable-threads \
              --enable-smp-support \
              --enable-kernel-poll \
              --enable-dynamic-ssl-lib \
              --enable-shared-zlib \
              --enable-hipe \
              --with-ssl="$(pkg_path_for openssl)/lib" \
              --with-ssl-include="$(pkg_path_for openssl)/include" \
              --without-javac
  make
}

do_end() {
  # Clean up the `pwd` link, if we set it up.
  if [[ -n "$_clean_pwd" ]]; then
    rm -fv /bin/pwd
  fi

  if [[ -n "$_clean_rm" ]]; then
    rm -fv /bin/rm
  fi
}
