# In ideal world every project would have it's own nix defintion
# this is hard to enforce so let's provide sane globals
# So work can be done

{ pkgs, ... }:
{
    environment.systemPackages = with pkgs.elmPackages; [
        elm
        elm-format
        pkgs.elm2nix
        elm-test
        elm-verify-examples
        elm-analyse
        elm-doc-preview
    ];
}
