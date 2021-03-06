{-# LANGUAGE QuasiQuotes #-}

---------------------------------------------------------------------------
--                                                                       --
--     _|      _|  _|      _|                                      _|    --
--       _|  _|    _|_|  _|_|    _|_|    _|_|_|      _|_|_|    _|_|_|    --
--         _|      _|  _|  _|  _|    _|  _|    _|  _|    _|  _|    _|    --
--       _|  _|    _|      _|  _|    _|  _|    _|  _|    _|  _|    _|    --
--     _|      _|  _|      _|    _|_|    _|    _|    _|_|_|    _|_|_|    --
--                                                                       --
---------------------------------------------------------------------------
-- Marek Fajkus <marek.faj@gmail.com> @turbo_MaCk                        --
-- https://github.com/turboMaCk                                          --
---------------------------------------------------------------------------
import           XMonad
import           XMonad.Actions.CopyWindow        (copyToAll)
import           XMonad.Hooks.DynamicLog
import           XMonad.Hooks.EwmhDesktops        (ewmh, fullscreenEventHook)
import qualified XMonad.Hooks.ManageDocks         as Docks
import           XMonad.Hooks.ManageHelpers       (doFullFloat, isFullscreen)
import qualified XMonad.Hooks.SetWMName           as WMName
import           XMonad.Layout.NoBorders          (smartBorders)
import           XMonad.Layout.Simplest           (Simplest (..))
import qualified XMonad.Layout.Tabbed             as Tabbed
import           XMonad.Layout.WorkspaceDir       (changeDir, workspaceDir)
import           XMonad.Prompt
import qualified XMonad.StackSet                  as W
import           XMonad.Util.NamedScratchpad
import           XMonad.Util.Scratchpad           (scratchpadManageHook,
                                                   scratchpadSpawnActionTerminal)
import           XMonad.Util.SpawnOnce            (spawnOnce)
import           XMonad.Layout.Spacing            (smartSpacing)

import qualified Codec.Binary.UTF8.String         as UTF8
import qualified DBus                             as D
import qualified DBus.Client                      as D

import qualified Data.Map                         as M
import           Data.Monoid                      (Endo)
import           System.Exit                      (ExitCode (ExitSuccess),
                                                   exitWith)
import           Text.RawString.QQ


import           Graphics.X11.ExtraTypes.XF86
import qualified XMonad.Actions.Volume            as Volume
import           XMonad.Layout.BoringWindows
import           XMonad.Layout.Decoration         (shrinkText)
import           XMonad.Layout.MouseResizableTile (mouseResizableTile)
import           XMonad.Layout.ResizableTile
import           XMonad.Layout.SubLayouts
import           XMonad.Layout.WindowNavigation
import qualified XMonad.Util.Brightness           as Brightness


-------------------------------------
-- Main
-------------------------------------

main :: IO ()
main = do
  dbus <- D.connectSession
  -- Request access to DBus name
  D.requestName dbus (D.busName_ "org.xmonad.Log")
    [ D.nameAllowReplacement, D.nameReplaceExisting, D.nameDoNotQueue ]

  xmonad $ ewmh $ myConfig
    { logHook = dynamicLogWithPP (myLogHook dbus) }

-------------------------------------
-- Config
-------------------------------------

myTerminal :: String
myTerminal = "urxvt"

red   = "#fb4934"
bg1   = "#3c3836"
bg2   = "#504945"
blue  = "#2E9AFE"
black = "#000000"

-- Override the PP values as you would otherwise, adding colors etc depending
-- on  the statusbar used

myLogHook :: D.Client -> PP
myLogHook dbus = def
    { ppOutput  = dbusOutput dbus
    , ppCurrent = wrap ("%{B" ++ bg2 ++ "} ") " %{B-}"
    , ppVisible = wrap ("%{B" ++ bg1 ++ "} ") " %{B-}"
    , ppUrgent  = wrap ("%{F" ++ red ++ "} ") " %{F-}"
    , ppHidden  = wrap " " " "
    , ppWsSep   = ""
    , ppSep     = " : "
    , ppTitle   = shorten 40
    }


-- Emit a DBus signal on log updates
dbusOutput :: D.Client -> String -> IO ()
dbusOutput dbus str = do
    let signal = (D.signal objectPath interfaceName memberName) {
            D.signalBody = [D.toVariant $ UTF8.decodeString str]
        }
    D.emit dbus signal
  where
    objectPath    = D.objectPath_ "/org/xmonad/Log"
    interfaceName = D.interfaceName_ "org.xmonad.Log"
    memberName    = D.memberName_ "Update"



-- Main configuration, override the defaults to your liking.
myConfig = def
  { modMask            = mod4Mask
  , terminal           = myTerminal
  , workspaces         = myWorkspaces
  , keys               = myKeys
  , layoutHook         = myLayoutHook
  , focusedBorderColor = blue
  , normalBorderColor  = black
  , manageHook         = myManageHook
                          <+> manageHook def
                          <+> Docks.manageDocks
                          <+> manageScratchPad
  , handleEventHook    = Docks.docksEventHook
                          <+> fullscreenEventHook
  , borderWidth        = 4
  , startupHook        = myStartupHook
  }

-- then define your scratchpad management separately:
manageScratchPad :: ManageHook
manageScratchPad = scratchpadManageHook (W.RationalRect l t w h)
  where
    h = 0.3     -- terminal height, 30%
    w = 1       -- terminal width, 100%
    t = 1 - h   -- distance from top edge, 90%
    l = 1 - w   -- distance from left edge, 0%


scratchpads = [ NS "htop" "urxvt -e htop" (title =? "htop") defaultFloating
              , NS "obs" "obs" (className =? ".obs-wrapped") defaultFloating
              , NS "peek" "peek" (className =? "Peek") defaultFloating
              , NS "slack" "slack" (className =? "slack") defaultFloating
              , NS "discord" "Discord" (className =? "discord") defaultFloating
              , NS "keybase-gui" "keybase-gui" (className =? "Keybase") defaultFloating
              , NS "gnome-calculator" "gnome-calculator" (title =? "Calculator") defaultFloating
              ] where role = stringProperty "WM_WINDOW_ROLE"


xmobarEscape :: String -> String
xmobarEscape = concatMap doubleLts
  where doubleLts '<' = "<<"
        doubleLts x   = [x]


webW = "1"
communicateW = "2"
emailW = "3"
codeW = "4"
musicW = "8"
virtualW = "9"


myWorkspaces :: [String]
myWorkspaces = clickable . (map xmobarEscape) $
  [ webW
  , communicateW
  , emailW
  , codeW
  , "5"
  , "6"
  , "7"
  , musicW
  , virtualW ]
  where
    clickable l =
      [ ws |
        (i , ws) <- zip [1..10] l,
        let n = i
      ]


-------------------------------------
-- Keys
-------------------------------------

rofi :: String
rofi = [r|
  rofi -show run -modi run -locat4on 1 -width 50 \
                 -lines 10 -line-margin 3 -line-padding 1 \
                 -font "mono 10" -columns 1 -bw 0 \
                 -color-window "#222222, #222222, #b1b4b3" \
                 -color-normal "#222222, #b1b4b3, #222222, #005577, #b1b4b3" \
                 -color-active "#222222, #b1b4b3, #222222, #007763, #b1b4b3" \
                 -color-urgent "#222222, #b1b4b3, #222222, #77003d, #b1b4b3" \
                 -kb-row-select "Tab" -kb-row-tab ""|]

myKeys conf@(XConfig { XMonad.modMask = modMasq }) = M.fromList $

    -- launch a terminal
    [ ((modMasq .|. shiftMask, xK_t     ), spawn myTerminal)

    -- set directory
    , ((modMasq .|. shiftMask, xK_x     ), changeDir def)

    -- launch a browser
    , ((modMasq .|. shiftMask, xK_b    ), spawn "brave")

    -- launch emacs client frame
    , ((modMasq .|. shiftMask, xK_o    ), spawn "emacsclient -n -c")

    -- screenshot
    , ((modMasq .|. shiftMask, xK_p    ), spawn "flameshot gui")

    -- launch rofi
    , ((modMasq,               xK_p     ), spawn rofi)

    -- launch fori-pass
    , ((modMasq,               xK_o     ), spawn "rofi-pass")

    -- launch ranger
    , ((modMasq .|. shiftMask, xK_m     ), spawn $ myTerminal ++ " -e lf")


    -- close focused window
    , ((modMasq,               xK_q     ), kill)

     -- Rotate through the available layout algorithms
    , ((modMasq,               xK_space ), sendMessage NextLayout)

    --  Reset the layouts on the current workspace to default
    , ((modMasq .|. shiftMask, xK_space ), setLayout $ XMonad.layoutHook conf)

    -- Resize viewed windows to the correct size
    , ((modMasq,               xK_n     ), refresh)

    -- Move focus to the next window
    -- , ((modMasq,               xK_Tab   ), windows $ W.swapMaster . W.focusDown . W.focusMaster)
    , ((modMasq,               xK_Tab   ), focusDown)

    -- Move focus to the next window
    , ((modMasq,               xK_j     ), focusDown)

    -- Move focus to the previous window
    , ((modMasq,               xK_k     ), focusUp)

    -- Move focus to the master window
    , ((modMasq,               xK_m     ), windows W.focusMaster)

    , ((modMasq,               xK_a     ), windows copyToAll)

    -- Swap the focused window and the master window
    , ((modMasq,               xK_Return), windows W.swapMaster)

    -- swap the focused window with the next window
    , ((modMasq .|. shiftMask, xK_j     ), windows W.swapDown)

    -- Swap the focused window with the previous window
    , ((modMasq .|. shiftMask, xK_k     ), windows W.swapUp)

    -- Shrink the master area
    , ((modMasq,               xK_h     ), sendMessage Shrink)

    -- Expand the master area
    , ((modMasq,               xK_l     ), sendMessage Expand)

    -- Push window back into tiling
    , ((modMasq,               xK_t     ), withFocused $ windows . W.sink)

    -- Increment the number of windows in the master area
    , ((modMasq              , xK_comma ), sendMessage (IncMasterN 1))

    -- Deincrement the number of windows in the master area
    , ((modMasq              , xK_period), sendMessage (IncMasterN (-1)))

    -- Marks as booring
    , ((modMasq              , xK_i     ), markBoring)
    , ((modMasq              , xK_u     ), clearBoring)

    -- Quit xmonad
    , ((modMasq .|. shiftMask, xK_c     ), io (exitWith ExitSuccess))

    -- Sratchpads
    , ((modMasq .|. shiftMask, xK_f     ), namedScratchpadAction scratchpads "slack")
    , ((modMasq .|. shiftMask, xK_d     ), namedScratchpadAction scratchpads "discord")
    , ((modMasq .|. shiftMask, xK_g     ), namedScratchpadAction scratchpads "peek")
    , ((modMasq .|. shiftMask, xK_h     ), namedScratchpadAction scratchpads "obs")
    , ((modMasq .|. shiftMask, xK_s     ), namedScratchpadAction scratchpads "keybase-gui")
    , ((modMasq .|. shiftMask, xK_a     ), namedScratchpadAction scratchpads "gnome-calculator")

    -- Struts...
    , ((modMasq, xK_b                   ), sendMessage $ Docks.ToggleStrut Docks.U)

    -- Restart xmonad
    , ((modMasq .|. shiftMask, xK_q     ), spawn "xmonad --recompile; ~/.xmonad/kill.sh; notify-send \"XMonad\" \"Reloaded!\"; xmonad --restart")


    -- TODO: review
    , ((modMasq .|. controlMask, xK_h   ), sendMessage $ pullGroup L)
    , ((modMasq .|. controlMask, xK_l   ), sendMessage $ pullGroup R)
    , ((modMasq .|. controlMask, xK_k   ), sendMessage $ pullGroup U)
    , ((modMasq .|. controlMask, xK_j   ), sendMessage $ pullGroup D)
    , ((modMasq .|. controlMask, xK_m   ), withFocused (sendMessage . MergeAll))
    , ((modMasq .|. controlMask, xK_u   ), withFocused (sendMessage . UnMerge))
    , ((modMasq .|. shiftMask, xK_comma ), onGroup W.focusUp')
    , ((modMasq .|. shiftMask, xK_period), onGroup W.focusDown')
    , ((modMasq,               xK_z     ), sendMessage MirrorShrink)
    , ((modMasq,               xK_s     ), sendMessage MirrorExpand)

    -- TODO: review
    -- Media

    -- VOLUME
    , ((0, xF86XK_AudioMute             ), Volume.toggleMute >> pure ())
    , ((0, xF86XK_AudioLowerVolume      ), Volume.lowerVolume 10 >> pure ())
    , ((0, xF86XK_AudioRaiseVolume      ), Volume.raiseVolume 10 >> pure ())
    , ((0, xF86XK_AudioMicMute          ), spawn micMuteToggleScript)

    -- Brightness
    , ((0, xF86XK_MonBrightnessUp       ), Brightness.increase)
    , ((0, xF86XK_MonBrightnessDown     ), Brightness.decrease)
    ]
    ++

    --
    -- mod-[1..9], Switch to workspace N
    --
    -- mod-[1..9], Switch to workspace N
    -- mod-shift-[1..9], Move client to workspace N
    --
    [((m .|. modMasq, k)
     , windows $ f i)
        | (i, k) <- zip (XMonad.workspaces conf) [xK_1 .. xK_9]
        , (f, m) <- [(W.greedyView, 0), (W.shift, shiftMask)]
        ]
    ++

    --
    -- mod-{w,e,r}, Switch to physical/Xinerama screens 1, 2, or 3
    -- mod-shift-{w,e,r}, Move client to screen 1, 2, or 3
    --
    [((m .|. modMasq, key), screenWorkspace sc >>= flip whenJust (windows . f))
        | (key, sc) <- zip [xK_w, xK_e, xK_r] [0..]
        , (f, m) <- [(W.view, 0), (W.shift, shiftMask)]]


micMuteToggleScript :: String
micMuteToggleScript = unlines
  [ "if [[ $(amixer sget Capture) == *\"[on]\"* ]]; then"
  , "  amixer sset Capture nocap"
  , "else"
  , "  amixer sset Capture cap"
  , "fi"
  ]

-------------------------------
-- spawn processes
-------------------------------


myStartupHook :: X ()
myStartupHook = do
  spawn "feh --bg-center ~/Dotfiles/images/wallpaper.jpg"
  spawn "polybar example"
  spawn "imwheel --kill --buttons 45"
  -- Java Apps might require this
  -- WMName.setWMName "LG3D"


myManageHook :: Query (Endo WindowSet)
myManageHook = composeAll
    [ className =? "stalonetray"  --> doIgnore
    , className =? ".obs-wrapped" --> doFloat
    , className =? "Peek"         --> doFloat
    , className =? "slack"        --> doFloat -- not working properly it seems
    , className =? "discord"      --> doFloat
    , className =? "Gimp"         --> doFloat
    , className =? "Keybase"      --> doFloat
    , className =? "Calculator"   --> doFloat
    , Docks.manageDocks
    , isFullscreen                --> doF W.focusDown <+> doFullFloat
    ]


-------------------------------
-- layouts
-------------------------------

tabbedConf :: Tabbed.Theme
tabbedConf =
  Tabbed.defaultTheme
  { Tabbed.activeColor = blue
  , Tabbed.activeBorderColor = blue
  , Tabbed.inactiveColor = bg1
  , Tabbed.inactiveBorderColor = bg1
  , Tabbed.activeTextColor = black
  }

myLayoutHook = Docks.avoidStruts $ smartBorders $ workspaceDir "/home/marek" $ windowNavigation
  tall
  ||| wide
  ||| (boringAuto Simplest)
  where
    tall = Tabbed.addTabs shrinkText tabbedConf
      $ smartSpacing 5
      $ subLayout [] Simplest
      $ boringWindows
      $ ResizableTall 1 (3/100) (2/3) []
    wide = boringAuto
      $ smartSpacing 5
      $ Mirror $ ResizableTall 1 (2/100) (5/6) []

-- Local Variables:
-- flycheck-ghc-args: ("-Wno-missing-signatures")

-- End:
