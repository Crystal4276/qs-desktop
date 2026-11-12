/* SPDX-License-Identifier: GPL-3.0-or-later
 * Presentation and grouping only: preserve original boot source, IDs and arguments. */
#include <grub/dl.h>
#include <grub/command.h>
#include <grub/env.h>
#include <grub/mm.h>
#include <grub/misc.h>
#include <grub/video.h>
#include <grub/normal.h>
GRUB_MOD_LICENSE ("GPLv3+");
static grub_command_t video_cmd, entry_cmd, group_cmd, open_cmd;
static grub_menu_t fallbacks;
static grub_err_t video (grub_command_t cmd __attribute__((unused)), int argc __attribute__((unused)), char **argv __attribute__((unused)))
{
  struct grub_video_mode_info info;
  char *mode;
  char rows[] = "7";
  grub_menu_t menu;
  grub_err_t err = grub_video_get_info (&info);
  if (err) return err;
  mode = grub_xasprintf ("%ux%u", info.width, info.height);
  if (!mode) return grub_errno;
  err = grub_env_set ("qs_horizon_mode", mode);
  grub_free (mode);
  if (err) return err;
  menu = grub_env_get_menu ();
  if (menu && menu->size > 0 && menu->size < 7)
    rows[0] = '0' + menu->size;
  return grub_env_set ("qs_horizon_rows", rows);
}
static grub_err_t entry (grub_command_t cmd __attribute__((unused)), int argc, char **argv)
{
  grub_menu_t menu = grub_env_get_menu ();
  grub_menu_entry_t e;
  if (argc != 3) return grub_error (GRUB_ERR_BAD_ARGUMENT, "expected ID TITLE CLASS");
  if (!menu) return GRUB_ERR_NONE;
  for (e = menu->entry_list; e; e = e->next)
    if (e->id && grub_strcmp (e->id, argv[0]) == 0)
      {
        char *title = grub_strdup (argv[1]);
        struct grub_menu_entry_class *c, *cls;
        int count = 0, i = 1;
        for (c = e->classes; c; c = c->next) count++;
        cls = grub_zalloc ((count + 1) * sizeof (*cls));
        if (!title || !cls) { grub_free (title); grub_free (cls); return grub_errno; }
        cls[0].name = grub_strdup (argv[2]);
        if (!cls[0].name) { grub_free (title); grub_free (cls); return grub_errno; }
        for (c = e->classes; c; c = c->next) cls[i++].name = c->name;
        for (i = 0; i < count; i++) cls[i].next = &cls[i + 1];
        grub_free (e->classes); e->classes = cls;
        grub_free ((void *) e->title); e->title = title;
        break;
      }
  return GRUB_ERR_NONE;
}
/* Kept originals own their metadata. The native submenu gets independent copies. */
static void release_fallbacks (void)
{
  grub_menu_t current = grub_env_get_menu ();
  if (fallbacks) grub_normal_free_menu (fallbacks);
  fallbacks = NULL;
  grub_env_set_menu (current);
}
static int matches (grub_menu_entry_t e, int argc, char **argv)
{
  int i;
  for (i = 0; e->id && i < argc; i++)
    if (grub_strcmp (e->id, argv[i]) == 0) return 1;
  return 0;
}
static grub_menu_entry_t default_selection (grub_menu_t menu, const char *value)
{
  grub_menu_entry_t e;
  const char *suffix, *end;
  char *key;
  unsigned long index;
  if (!value) return menu->entry_list;
  suffix = grub_strchr (value, '>');
  key = grub_strndup (value, suffix ? (grub_size_t) (suffix - value) : grub_strlen (value));
  if (!key) return NULL;
  for (e = menu->entry_list; e; e = e->next)
    if ((e->id && grub_strcmp (key, e->id) == 0) || grub_strcmp (key, e->title) == 0)
      { grub_free (key); return e; }
  index = grub_strtoul (key, &end, 0);
  e = !grub_errno && !*end && index < (unsigned long) menu->size
        ? grub_menu_get_entry (menu, index) : menu->entry_list;
  grub_errno = GRUB_ERR_NONE;
  grub_free (key);
  return e;
}
static grub_err_t group (grub_command_t cmd __attribute__((unused)), int argc, char **argv)
{
  grub_menu_t menu = grub_env_get_menu (), kept;
  grub_menu_entry_t e, selected, advanced, *link, *tail;
  const char *args[] = {"Advanced options"};
  char advanced_class[] = "advanced";
  char *classes[] = {advanced_class, NULL};
  char *newdefault;
  const char *suffix, *olddefault = grub_env_get ("default");
  int i, count = 0;
  grub_err_t err;
  if (!menu || !argc) return GRUB_ERR_NONE;
  for (e = menu->entry_list; e; e = e->next)
    {
      /* Never replace a user's existing Advanced options submenu. */
      if (e->id && grub_strcmp (e->id, "advanced-options") == 0) return GRUB_ERR_NONE;
      if (matches (e, argc, argv)) count++;
    }
  if (!count) return GRUB_ERR_NONE;
  selected = default_selection (menu, olddefault);
  if (!selected && grub_errno) return grub_errno;
  suffix = olddefault ? grub_strchr (olddefault, '>') : NULL;
  /* A saved nested selection refers to a submenu that is about to be recreated. */
  if (olddefault && grub_strncmp (olddefault, "advanced-options>", 17) == 0)
    for (e = menu->entry_list; e; e = e->next)
      if (e->id && grub_strcmp (e->id, olddefault + 17) == 0 && matches (e, argc, argv))
        { selected = e; suffix = NULL; break; }
  newdefault = selected ? grub_xasprintf ("%s%s%s",
                matches (selected, argc, argv) ? "advanced-options>" : "",
                selected->id, suffix ? suffix : "") : NULL;
  kept = grub_zalloc (sizeof (*kept));
  if (!kept || (selected && !newdefault))
    { grub_free (kept); grub_free (newdefault); return grub_errno; }
  err = grub_normal_add_menu_entry (1, args, classes, "advanced-options", NULL, NULL, NULL,
        "qs_horizon_fallback_menu\nsource $prefix/themes/qs-horizon/select.cfg\n", 1, NULL);
  if (err) { grub_free (kept); grub_free (newdefault); return err; }
  /* The native constructor appends: move that new submenu to the first fallback slot. */
  for (link = &menu->entry_list; (*link)->next; link = &(*link)->next);
  advanced = *link; *link = NULL;
  if (newdefault && (err = grub_env_set ("default", newdefault)))
    {
      kept->entry_list = advanced; kept->size = 1; menu->size--;
      grub_normal_free_menu (kept); grub_env_set_menu (menu);
      grub_free (newdefault); return err;
    }
  for (link = &menu->entry_list; *link && !matches (*link, argc, argv); link = &(*link)->next);
  advanced->next = *link; *link = advanced;
  tail = &kept->entry_list;
  for (i = 0; i < argc; i++)
    for (link = &menu->entry_list; *link; link = &(*link)->next)
      if ((*link)->id && grub_strcmp ((*link)->id, argv[i]) == 0)
        {
          e = *link; *link = e->next; e->next = NULL;
          *tail = e; tail = &e->next; kept->size++; menu->size--; break;
        }
  release_fallbacks (); fallbacks = kept;
  grub_free (newdefault);
  return err;
}
static grub_err_t open_fallbacks (grub_command_t cmd __attribute__((unused)),
                                int argc __attribute__((unused)), char **argv __attribute__((unused)))
{
  grub_menu_entry_t e, copy;
  grub_menu_t menu = grub_env_get_menu ();
  if (!fallbacks || !menu) return GRUB_ERR_NONE;
  for (e = fallbacks->entry_list; e; e = e->next)
    {
      struct grub_menu_entry_class *c;
      char **classes, *title;
      grub_err_t err;
      int n = 0, i = 0;
      for (c = e->classes; c; c = c->next) n++;
      classes = grub_zalloc ((n + 1) * sizeof (*classes));
      title = grub_strdup (e->title);
      if (!classes || !title) { grub_free (classes); grub_free (title); return grub_errno; }
      for (c = e->classes; c; c = c->next) classes[i++] = c->name;
      err = grub_normal_add_menu_entry (e->argc, (const char **) e->args, classes,
              e->id, e->users, NULL, NULL, e->sourcecode, e->submenu, e->blsuki);
      grub_free (classes);
      if (err) { grub_free (title); return err; }
      copy = grub_menu_get_entry (menu, menu->size - 1);
      grub_free ((void *) copy->title); copy->title = title;
      copy->hotkey = e->hotkey; copy->restricted = e->restricted;
    }
  return GRUB_ERR_NONE;
}
GRUB_MOD_INIT(horizon)
{
  video_cmd = grub_register_command ("qs_horizon_video", video, "", "Read active video dimensions.");
  group_cmd = grub_register_command ("qs_horizon_group", group, "ID...", "Group existing fallback entries without changing their boot commands.");
  open_cmd = grub_register_command ("qs_horizon_fallback_menu", open_fallbacks, "", "Populate native fallback submenu.");
  entry_cmd = grub_register_command ("qs_horizon_entry", entry, "ID TITLE CLASS", "Set menu presentation only.");
}
GRUB_MOD_FINI(horizon)
{
  release_fallbacks ();
  grub_unregister_command (group_cmd); grub_unregister_command (open_cmd);
  grub_unregister_command (video_cmd); grub_unregister_command (entry_cmd);
}
