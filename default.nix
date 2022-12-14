{ pkgs ? import <nixpkgs> {}}: {
  yocto_kirkstone = import ./yocto/kirkstone/shell.nix { inherit pkgs; };
  yocto_kirkstone_zsh = import ./yocto/kirkstone/shell.nix { inherit pkgs; };
  yocto_kirkstone_fish = import ./yocto/kirkstone/shell.nix { inherit pkgs; user-shell="fish"; };
  yocto_kirkstone_bash = import ./yocto/kirkstone/shell.nix { inherit pkgs; user-shell="bash"; };

  yocto_kirkstone_pure = import ./yocto/kirkstone/shell.nix { inherit pkgs; kerberos=false; ldap=false; };
  yocto_kirkstone_pure_zsh = import ./yocto/kirkstone/shell.nix { inherit pkgs; kerberos=false; ldap=false; };
  yocto_kirkstone_pure_fish = import ./yocto/kirkstone/shell.nix { inherit pkgs; user-shell="fish"; kerberos=false; ldap=false; };
  yocto_kirkstone_pure_bash = import ./yocto/kirkstone/shell.nix { inherit pkgs; user-shell="bash"; kerberos=false; ldap=false; };

  yocto_kirkstone_docker = import ./yocto/kirkstone/shell.nix { inherit pkgs; docker=true; };
  yocto_kirkstone_zsh_docker = import ./yocto/kirkstone/shell.nix { inherit pkgs; docker=true; };
  yocto_kirkstone_fish_docker = import ./yocto/kirkstone/shell.nix { inherit pkgs; user-shell="fish"; docker=true; };
  yocto_kirkstone_bash_docker = import ./yocto/kirkstone/shell.nix { inherit pkgs; user-shell="bash"; docker=true; };
  
  yocto_kirkstone_pure_docker = import ./yocto/kirkstone/shell.nix { inherit pkgs; kerberos=false; ldap=false; docker=true; };
  yocto_kirkstone_pure_zsh_docker = import ./yocto/kirkstone/shell.nix { inherit pkgs; kerberos=false; ldap=false; docker=true; };
  yocto_kirkstone_pure_fish_docker = import ./yocto/kirkstone/shell.nix { inherit pkgs; user-shell="fish"; kerberos=false; ldap=false; docker=true;};
  yocto_kirkstone_pure_bash_docker = import ./yocto/kirkstone/shell.nix { inherit pkgs; user-shell="bash"; kerberos=false; ldap=false; docker=true;};
}
