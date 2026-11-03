-- Entrées, curseur, dispositions et divers.

hl.config({
   input = {
      kb_layout = "us",
      -- Les kb_variant / kb_model / kb_options / kb_rules de hyprland.conf
      -- étaient des assignations vides : on les omet simplement.

      numlock_by_default = true,
      follow_mouse       = 1,
      sensitivity        = 0, -- -1.0 à 1.0, 0 = aucune modification

      touchpad = {
         natural_scroll = false,
      },
   },

   dwindle = {
      -- `pseudotile` a disparu du schéma Lua (absent de HL.ConfigOpt.Dwindle
      -- dans les stubs) : la ligne n'est pas reportée. Le bind SUPER+P, qui
      -- appelle hl.dsp.window.pseudo(), n'en dépend pas.
      preserve_split = true,
   },

   master = {
      new_status = "master",
   },

   misc = {
      focus_on_activate          = false,
      mouse_move_enables_dpms    = true,
      key_press_enables_dpms     = true,
      mouse_move_focuses_monitor = true,
      initial_workspace_tracking = 0,
      disable_hyprland_logo      = true,
      disable_splash_rendering   = true,
      force_default_wallpaper    = 0,
      -- Introduit en 0.53 : remplace new_window_takes_over_fullscreen et
      -- master:inherit_fullscreen.
      on_focus_under_fullscreen  = 0,
      -- Quickshell relancé après un arrêt pendant le verrouillage : la nouvelle instance reprend le verrou (défaut : false,
      -- la session resterait sur l'écran « verrouillage mort » ; modules/lock/LockScreen.qml).
      allow_session_lock_restore = true,
   },

   cursor = {
      sync_gsettings_theme = false,
      use_cpu_buffer       = true,
      no_warps             = true,
      -- default_monitor : propre à la machine (hosts/<hostname>.lua).
   },
})

-- Le bloc `device { name = epic-mouse-v1 }` de hyprland.conf n'est pas reporté :
-- c'est du boilerplate venu de la config d'exemple amont, pour un périphérique
-- qui n'a jamais été branché sur cette machine (vérifiable avec `hyprctl
-- devices`). La forme Lua serait hl.device({ name = "...", sensitivity = ... }).
