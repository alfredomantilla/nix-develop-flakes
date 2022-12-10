nix develop .#yocto_kirkstone (if experimental features command and flakes are enabled in nix, otherwise nix --extra-experimental-features "nix-command flakes" develop .#yocto_kirkstone)

Will provide a ready to use environment that is reproducible on WSL, Linux and MacOS for use under a company infrastructure that relies on krb5 and NSS

nix develop .#yocto_kirkstone_pure (if experimental features command and flakes are enabled in nix, otherwise nix --extra-experimental-features "nix-command flakes" develop .#yocto_kirkstone_pure)

Will otherwise remove the dependencies from that infrastructure and can be used on personal machines

Also a set of suffixes for the shells are provided i.e yocto_kirkstone_pure_zsh will provide zsh as shell and yocto_kirkstone_pure_fish will provide fish as the develop shell
