{ config, pkgs, ... }:

{
  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.extraUsers.marek = {
    description = "Marek Fajkus (@turbo_MaCk)";
    isNormalUser = true;
    uid = 1000;

    extraGroups = [
      "wheel"
      "networkmanager"
      "vboxusers"
      "docker"
    ];

    # Shell
    shell = pkgs.zsh;

    packages = with pkgs; [
        rxvt_unicode
        steam
        browserpass
        dropbox
        obs-sudio
        slack
        spotify
        emacs25
        wire-desktop
        ranger
        ag
        vlc
        gource
    ];
  };

  ## Systemd Services

  systemd.user.services."urxvtd" = {
    enable = true;
    description = "rxvt unicode daemon";
    wantedBy = [ "default.target" ];
    path = [ pkgs.rxvt_unicode ];
    serviceConfig.Restart = "always";
    serviceConfig.RestartSec = 2;
    serviceConfig.ExecStart = "${pkgs.rxvt_unicode}/bin/urxvtd -q -o";
  };
}
