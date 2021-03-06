# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, ... }:

{
  nixpkgs = {
    config.allowBroken = true;
    overlays = [
      (import ../overlays/pkgs.nix)
      (import ../overlays/haskell.nix)
    ];
  };

  imports =
    [ <nixos-hardware/common/pc/ssd>
      ../profiles/base.nix
      ../profiles/desktop.nix
      ../users/marek.nix
      ../profiles/virtualization.nix
      ../profiles/elm.nix
      ../profiles/nodejs.nix
      ../profiles/haskell.nix
      ../profiles/purescript.nix
      ../profiles/rust.nix
      ../profiles/ocaml.nix
      # Extra
      ../profiles/unison.nix
      ../profiles/heroku.nix
      ../profiles/stream.nix
      ../profiles/gaming.nix
    ];

  # Use the systemd-boot EFI boot loader.
  boot = {
    loader = {
      systemd-boot.enable = true;
      efi.canTouchEfiVariables = true;
    };
    # Latest kernel
    # not using latest due to issue with virtual box compilation
    kernelPackages = pkgs.linuxPackages_5_4;
  };

  networking = {
    hostName = "nixos-mainframe"; # Define your hostname.
    networkmanager = {
      enable = true;
      enableStrongSwan = true;
      extraConfig = ''
        [main]
        rc-manager=resolvconf
      '';
    };
  };

  services.strongswan = {
    enable = true;
    secrets = [
      # see https://github.com/NixOS/nixpkgs/issues/64965
      "ipsec.d/ipsec.nm-l2tp.secrets"
    ];
  };

  # Set your time zone.
  time.timeZone = "Europe/Prague";

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [];

  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.bash.enableCompletion = true;
  # programs.mtr.enable = true;

  # List services that you want to enable:

  # Enable the OpenSSH daemon.

  # services.openssh.enable = true;
  # programs.ssh.startAgent = true;

  # Open ports in the firewall.
  # networking.firewall.allowedTCPPorts = [ ... ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  # Or disable the firewall altogether.
  # networking.firewall.enable = false;

  # Enable CUPS to print documents.
  services.printing.enable = true;

  # Enable sound.
  sound.enable = true;

  hardware = {
    # graphic card requires this (AMDGPU)
    enableRedistributableFirmware = true;

    opengl = {
      enable = true;
      driSupport = true;
    };

    # HW support
    pulseaudio = {
      # Sound config
      enable = true;
      package = pkgs.pulseaudioFull;
      extraModules = [ pkgs.pulseaudio-modules-bt ];
      support32Bit = true;
    };

    # Bluetooth
    bluetooth = {
      enable = true;
    };

    cpu.amd.updateMicrocode = true;
  };

  # XORG
  services.xserver = {
   dpi = 130;
   videoDrivers = [ "amdgpu" ];

   libinput.enable = false; # touchbar

   imwheel = {
     enable = true;
     rules = {
       "chrom*|slack|discord|evolution|Firefox|brave-browser" = ''
        None,      Up,   Button4, 8
        None,      Down, Button5, 8
        Shift_L,   Up,   Shift_L|Button4, 4
        Shift_L,   Down, Shift_L|Button5, 4
        Control_L, Up,   Control_L|Button4
        Control_L, Down, Control_L|Button5
      '';
     };
     extraOptions = [
       "--buttons=45"
     ];
   };
  };

  # Set hosts
  # networking.hosts."128.199.58.247" = [ "planning-game.com" ];
  # networking.hosts."35.244.244.204" = ["app.globalwebindex.com"];

  # This value determines the NixOS release with which your system is to be
  # compatible, in order to avoid breaking some software such as database
  # servers. You should change this only after NixOS release notes say you
  # should.
  system.stateVersion = "19.03"; # Did you read the comment?
}
