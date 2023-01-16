
{ pkgs ? import <nixpkgs> {}, user-shell ? "zsh", kerberos ? true, ldap ? true , docker ? false}:

let
  shell-pkgs = if builtins.match user-shell "zsh" != null then (with pkgs; [
        zsh
        oh-my-zsh
        zsh-git-prompt
        zsh-powerlevel10k]) else if builtins.match user-shell "fish" != null then (with pkgs; [fish]) else (with pkgs; [bashInteractive]);
  base-pkgs = (with pkgs; [
        glibcLocales
        attr
        bc
        binutils-unwrapped
        bzip2
        chrpath
        cpio
        diffstat
        expect
        file
        gcc
#       not really needed
        gdb
        git
        gnumake
        hostname
        kconfig-frontends
        xz
        ncurses
        patch
        perl
        rpcsvc-proto
        unzip
# has systemd and some stuff not needed
        util-linux
        wget
        which
        lz4
        zstd
        zlib
        nano
        (python3.withPackages ( ps: with ps; [ jsonschema pyyaml kconfiglib distro pip (callPackage ./kas.nix {}) ]))
        # To use ssh properly with TTTech infra and this OpenBSD version of ssh you will need a key generated with "ssh-keygen -t ed25519"
        openssh
        # Need this on our build machines as groups and user come from LDAP
        sssd
        # Needed for menuconfig
        screen
        krb5
        dtc
        ccache
        fakeroot
        libselinux
        bubblewrap
        gzip
        pigz
        gnutar
        sudo
        less
        getconf
        bintools
        sqlite
        # ldd and iconv
        (pkgs.lib.getBin pkgs.stdenv.cc.libc)
        libgccjit
      ]);
  os-utils = (with pkgs; [ coreutils findutils gnutls gnused gnugrep gawk diffutils which libarchive dockerTools.binSh dockerTools.usrBinEnv cacert gosu glibc.dev ]);
  rootprofile = pkgs.writeText ".profile" ''
    if [ -f /etc/profile ]; then
      source /etc/profile
    fi
  '';
  fhsprofile =
      let
        wrapperEnvar = "NIX_CC_WRAPPER_TARGET_HOST_${pkgs.stdenv.cc.suffixSalt}";
        # TODO limit export to native pkgs?
        nixconf = pkgs.writeText "nixvars.conf" ''
          # This exports the variables to actual build environments
          # From BB_ENV_EXTRAWHITE
          export LOCALE_ARCHIVE
          export ${wrapperEnvar}
          export NIX_DONT_SET_RPATH = "1"
          # Exclude these when hashing
          # the packages in yocto
          BB_BASEHASH_IGNORE_VARS += " LOCALE_ARCHIVE \
                                    NIX_DONT_SET_RPATH \
                                    ${wrapperEnvar} "
        '';
      in
      ''
        # Need this on our build machines as groups and user come from LDAP, could be in another path, adjust properly
        ${pkgs.lib.optionalString ldap ''
        export LD_PRELOAD=/lib64/libnss_sss.so.2
        ''}
        # Yocto SSL certificate can cause problems with some git repos if this is not set
        export GIT_SSL_CAINFO=$NIX_SSL_CERT_FILE
        # Yocto SSL certificate can cause problems with some ftp repos if this is not set
        export SSL_CERT_FILE=$NIX_SSL_CERT_FILE
        # These are set by buildFHSUserEnvBubblewrap
        export BB_ENV_PASSTHROUGH_ADDITIONS=" LOCALE_ARCHIVE \
                                  ${wrapperEnvar} \
                                  $BB_ENV_PASSTHROUGH_ADDITIONS "
        # source the config for bitbake equal to --postread
        export BBPOSTCONF="${nixconf}"
      '';
  fhs = pkgs.buildFHSUserEnvBubblewrap {
    name = "yocto-fhs-${user-shell}";
    targetPkgs = pkgs: (pkgs.lib.concatLists [shell-pkgs base-pkgs]);
    extraOutputsToInstall = [ "dev" "lib" "share" "out" "bin" ];
    # Pass kerberos config to chroot if set to true
    extraBwrapArgs =
      let list = if kerberos then "--ro-bind /etc/krb5.conf /etc/krb5.conf" else "";
      in [list]; 

    runScript = "${user-shell}";
    extraInstallCommands = "";
    profile = "${fhsprofile}";
  };
  kas-os-release = let
    filterNull = pkgs.lib.filterAttrs (_: v: v != null);
    envFileGenerator = pkgs.lib.generators.toKeyValue { };
    os-release-params = {
      PORTABLE_ID = "debian";
      PORTABLE_PRETTY_NAME = "Ubuntu 14.04.3 LTS";
      HOME_URL = http://www.ttcontrol.com/;
      ID = "debian";
      PRETTY_NAME = "Potara Docker Build Distribution";
      BUILD_ID = "rolling";
    };
    os-release = pkgs.writeText "os-release"
      (envFileGenerator (filterNull os-release-params));
  in    
  pkgs.stdenv.mkDerivation {
      name = "kas-os-release";
      pname = "kas-os-release";

      buildCommand = ''
        # scaffold a file system layout
        mkdir -p $out/etc/systemd/system $out/proc $out/sys $out/dev $out/run \
                 $out/tmp $out/var/tmp $out/var/lib $out/var/cache $out/var/log
        # empty files to mount over with host's version
        touch $out/etc/resolv.conf $out/etc/machine-id
        # required for portable services
        cp ${os-release} $out/etc/os-release
      '';
  }; 
  
  etcProfile = pkgs.writeText "profile" ''
    export PS1='kirkstone-devel-fusion:\u@\h:\w\$ '
    export LOCALE_ARCHIVE='/usr/lib/locale/locale-archive'
    export LD_LIBRARY_PATH="/run/opengl-driver/lib:/run/opengl-driver-32/lib:/usr/lib:/usr/lib32''${LD_LIBRARY_PATH:+:}$LD_LIBRARY_PATH"
    export PATH="/run/wrappers/bin:/usr/bin:/usr/sbin:$PATH"
    export TZDIR='/etc/zoneinfo'
    # XDG_DATA_DIRS is used by pressure-vessel (steam proton) and vulkan loaders to find the corresponding icd
    export XDG_DATA_DIRS=$XDG_DATA_DIRS''${XDG_DATA_DIRS:+:}/run/opengl-driver/share:/run/opengl-driver-32/share
    # Force compilers and other tools to look in default search paths
    unset NIX_ENFORCE_PURITY
    export NIX_CC_WRAPPER_TARGET_HOST_${pkgs.stdenv.cc.suffixSalt}=1
    export NIX_CFLAGS_COMPILE='-idirafter /usr/include'
    export NIX_CFLAGS_LINK='-L/usr/lib -L/usr/lib32'
    export NIX_LDFLAGS='-L/usr/lib -L/usr/lib32'
    export PKG_CONFIG_PATH=/usr/lib/pkgconfig
    export ACLOCAL_PATH=/usr/share/aclocal
    export NIX_SSL_CERT_FILE=${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt
    # Yocto SSL certificate can cause problems with some git repos if this is not set
    export GIT_SSL_CAINFO=$NIX_SSL_CERT_FILE
    # Yocto SSL certificate can cause problems with some ftp repos if this is not set
    export SSL_CERT_FILE=$NIX_SSL_CERT_FILE
    ${fhsprofile}
  '';

  rootProfile = pkgs.writeText ".profile" ''
    if [ -f /etc/profile ]; then
      . /etc/profile
    fi
  '';

  # Compose /etc for the chroot environment
  etcPkg = pkgs.stdenv.mkDerivation {
    name         = "docker-profile";
    buildCommand = ''
      mkdir -p $out/etc
      cd $out/etc
      # environment variables
      ln -s ${etcProfile} profile
      mkdir -p $out/root
      cd $out/root
      ln -s ${rootProfile} .profile
      # symlink /etc/mtab -> /proc/mounts (compat for old userspace progs)
      ln -s /proc/mounts mtab
      mkdir -p $out/usr/lib/locale
      cd $out/usr/lib/locale
      ln -s ${pkgs.glibcLocales}/lib/locale/locale-archive locale-archive
      mkdir -p $out/tmp
      chmod 1777 $out/tmp
    '';
  };

  nonRootShadowSetup = { user, uid, gid ? uid }: with pkgs; [(
      writeTextDir "etc/shadow" ''
        root:!x:::::::
        ${user}:!:::::::
      ''
      )
      (
      writeTextDir "etc/passwd" ''
        root:x:0:0::/root:${runtimeShell}
        ${user}:x:${toString uid}:${toString gid}::/home/${user}:
      ''
      )
      (
      writeTextDir "etc/group" ''
        root:x:0:
        ${user}:x:${toString gid}:
      ''
      )
      (
      writeTextDir "etc/gshadow" ''
        root:x::
        ${user}:x::
      ''
      )];

  dockerImg = pkgs.dockerTools.buildLayeredImage   {
    name = "kirkstone_development_container_${user-shell}";
    tag = "latest";
    config.Env = [
      "SSL_CERT_FILE=${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt" 
    ];
    extraCommands = ''cp ${kas-os-release}/etc/os-release /etc/os-release 
                      # need the /usr/include folder
                      cp -r ${pkgs.glibc.dev}/include ./usr/
                    '';
    #config.Cmd = if builtins.match user-shell "zsh" != null then [ "${pkgs.zsh}/bin/zsh" ] 
    #     else if builtins.match user-shell "fish" != null then [ "${pkgs.fish}/bin/fish" ] 
    #     else [ "${pkgs.bashInteractive}/bin/bash" ]; 
    # Needed for mktemp
    fakeRootCommands = ''
        mkdir -p ./tmp
        chmod 1777 ./tmp
      '';
    config.Cmd = pkgs.writeScript "etc-cmd" ''
        #!${pkgs.bashInteractive}/bin/sh
        source ${etcPkg}/etc/profile
        ${pkgs.bashInteractive}/bin/bash
      '';
    config.User = "1000:1000";
    contents = pkgs.lib.concatLists [ shell-pkgs base-pkgs os-utils [ kas-os-release etcPkg ] ]  ++ nonRootShadowSetup { uid = 1000; user = "amn"; };
    maxLayers = 125;
  };
  Output = if docker then dockerImg else fhs.env;
in Output
