# Themes

Notes on the XFCE look I'm running. Both pieces are by **EliverLara** and are
designed to pair together (candy-icons was made to fit Sweet).

## What's set

- **GTK theme:** `Sweet-Dark`
- **xfwm4 (window manager) theme:** `Sweet-Dark`
- **Icon theme:** `candy-icons`

## Sources

- Sweet (GTK + xfwm4): https://github.com/EliverLara/Sweet
- candy-icons: https://github.com/EliverLara/candy-icons

## Install location

- GTK / xfwm4 themes: `~/.themes/Sweet-Dark/` (or `/usr/share/themes/`)
- Icons: `~/.icons/candy-icons/` (or `/usr/share/icons/`)

## Apply via xfconf-query

```
xfconf-query -c xsettings -p /Net/ThemeName -s Sweet-Dark
xfconf-query -c xsettings -p /Net/IconThemeName -s candy-icons
xfconf-query -c xfwm4    -p /general/theme     -s Sweet-Dark
```

## Check current values

```
xfconf-query -c xsettings -p /Net/ThemeName
xfconf-query -c xsettings -p /Net/IconThemeName
xfconf-query -c xfwm4    -p /general/theme
```

## TODO

Per `CLAUDE.md` rule 1 ("everything in the repo or it didn't happen"), the
actual install + xfconf-query lines should land in `common.sh` so a fresh
machine ends up with this theme automatically. This file is just the notes;
the script wiring is still pending.
