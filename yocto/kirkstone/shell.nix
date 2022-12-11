
{ pkgs ? import <nixpkgs> {}, user-shell ? "zsh", kerberos ? true, ldap ? true , docker ? false}:

let
  shell-pkgs = if builtins.match user-shell "zsh" != null then (with pkgs; [
        zsh
        oh-my-zsh
        zsh-git-prompt
        zsh-powerlevel10k]) else if builtins.match user-shell "fish" != null then (with pkgs; [fish]) else (with pkgs; []);
  base-pkgs = (with pkgs; [
        attr
        bc
        binutils
        bzip2
        chrpath
        cpio
        diffstat
        expect
        file
        gcc
        clang
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
        util-linux
        wget
        which
        glibcLocales
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
        ccache
        fakeroot
        libselinux
        bubblewrap
        krb5
        dtc
        sqlite
      ]);
  fhs = pkgs.buildFHSUserEnvBubblewrap {
    name = "yocto-fhs-${user-shell}";
    targetPkgs = pkgs: (pkgs.lib.concatLists [shell-pkgs base-pkgs]);
    extraOutputsToInstall = [ "dev" "lib" "share" ];
    # Pass kerberos config to chroot if set to true
    extraBwrapArgs =
      let list = if kerberos then "--ro-bind /etc/krb5.conf /etc/krb5.conf" else "";
      in [list]; 

    runScript = "${user-shell}";
    extraInstallCommands = "";
    profile =
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
  };
  dockerImg = pkgs.dockerTools.buildLayeredImage {
    name = "Kirkstone Development Container ${user-shell}";
    tag = "latest";
    extraCommands = ''echo "(extraCommand)" > extraCommands'';
    #config.Cmd = [ "${pkgs.hello}/bin/hello" ];
    contents = pkgs.lib.concatLists [shell-pkgs base-pkgs];
  };
  Output = if docker then dockerImg else fhs.env;
in Output
