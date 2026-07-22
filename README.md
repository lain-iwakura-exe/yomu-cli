# yomu-cli

Browse and read manga straight from your Linux terminal — no browser, no bloat.

Search titles, pick a volume/chapter with a fuzzy-search menu, and read the
pages rendered directly in your terminal emulator as pixel/character art.

## How it works

1. Queries the [MangaDex API](https://api.mangadex.org) for manga matching your search.
2. Lets you pick a manga, then a chapter, using an [`fzf`](https://github.com/junegunn/fzf) menu.
3. Downloads the chapter's pages and renders them in-terminal with
   [`chafa`](https://hpjansson.org/chafa/) (default) or the Kitty terminal's
   `icat` kitten (`--kitty`).

## Stack

| Tool    | Purpose                                              |
|---------|-------------------------------------------------------|
| `curl`  | Talks to the MangaDex REST API                        |
| `jq`    | Parses JSON payloads (titles, chapter IDs, image URLs) |
| `fzf`   | Interactive fuzzy menus for manga/chapter selection    |
| `chafa` | Renders page images as terminal graphics (default)     |
| `kitty` | Alternative renderer via the Kitty image protocol      |

## Prerequisites

Yomu needs `curl`, `jq`, `fzf`, and an image renderer (`chafa`, or `kitty` if
you use the Kitty terminal). Install these first with your distro's package
manager:

### Arch / CachyOS / EndeavourOS

```bash
sudo pacman -S curl jq fzf chafa
```

### Debian / Ubuntu / Linux Mint

```bash
sudo apt update
sudo apt install curl jq fzf chafa
```

### Fedora / Nobara

```bash
sudo dnf install curl jq fzf chafa
```

> Using the Kitty terminal instead? Install `kitty` via your distro's package
> manager and run the reader with `--kitty` — `icat` ships as a Kitty kitten,
> no extra package needed.

## Installation

The one-liner below detects your distro, installs the prerequisites above
automatically, and puts `yomu-cli` on your `PATH` so you can run it like any
other command:

```bash
curl -fsSL https://raw.githubusercontent.com/lain-iwakura-exe/yomu-cli/main/install.sh | bash
```

Prefer to install manually / review the script first?

```bash
git clone https://github.com/lain-iwakura-exe/yomu-cli.git
cd yomu-cli
chmod +x yomu-cli.sh install.sh
./install.sh
```

## Usage

Run it with no arguments for the interactive search prompt:

```bash
yomu-cli
```

Or pass the manga name straight in to jump right to results:

```bash
yomu-cli "one piece"
```

Optional flags (combine freely with a manga name):

```
-k, --kitty      Render pages with `kitty +kitten icat` instead of chafa
-c, --chafa      Render pages with chafa (default)
-l, --lang CODE  Filter chapters by language code (default: en)
-h, --help       Show help
```

```bash
yomu-cli "berserk" --kitty
yomu-cli "chainsaw man" --lang es
```

### Searching for a manga

1. Run `yomu-cli "manga name"` (or just `yomu-cli` for an interactive prompt).
2. A fuzzy-search menu opens with matching results. Keep typing to narrow it
   down, use the arrow keys to move, and press Enter to pick one.
3. A second menu shows that manga's chapters (volume, chapter number, title).
   Same deal — filter, select, Enter.
4. Yomu downloads that chapter's pages and opens the reader automatically.

While reading:

| Key           | Action        |
|---------------|---------------|
| Enter / `n`   | Next page     |
| `p`           | Previous page |
| `q`           | Quit          |

## Disclaimer

This project is an unofficial client for the MangaDex API, built for personal,
educational use. It doesn't host or distribute any content itself — all pages
are fetched live from MangaDex's public API. Respect MangaDex's
[API usage terms](https://api.mangadex.org/docs/) and the rights of manga
creators and publishers.

## License

MIT — see [LICENSE](LICENSE).
