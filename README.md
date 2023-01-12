# Scholar

Write academic articles in Markdown.

## Requirements

### Scholar requirements

- [Python 3.11](https://www.python.org/)
- [Pandoc 2.19](https://github.com/jgm/pandoc)
- [LaTeX](https://www.latex-project.org/)
- [Librsvg](https://wiki.gnome.org/Projects/LibRsvg) (if you want to use SVG
  images)
- [Pygments](https://pygments.org/) (if you want to use syntax highlighting)

### GOST style requirements

- [XITS](https://github.com/aliftype/xits)


## Usage

```sh
$ python -m scholar --help

 Usage: python -m scholar [OPTIONS] INPUT

 Convert the INPUT Markdown file to PDF.

╭─ Arguments ────────────────────────────────────────────────────────────────────────────────────────────────────────────────╮
│   input_file      INPUT  The input Markdown file. [default: None]                                                          │
╰────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────╯
╭─ Options ──────────────────────────────────────────────────────────────────────────────────────────────────────────────────╮
│ --output              -o      PATH                             The output file or directory. [default: (CWD)]              │
│ --style                       TEXT                             The style to use. [default: gost_thesis]                    │
│ --title-page                  FILE                             The title page to use. [default: None]                      │
│ --config                      FILE                             The YAML config file. [default: None]                       │
│ --from-tex                                                     Convert from LaTeX instead of Markdown.                     │
│ --to-tex                                                       Convert to LaTeX instead of PDF.                            │
│ --styles                                                       Show available styles and exit.                             │
│ --install-completion          [bash|zsh|fish|powershell|pwsh]  Install completion for the specified shell. [default: None] │
│ --show-completion             [bash|zsh|fish|powershell|pwsh]  Show completion for the specified shell, to copy it or      │
│                                                                customize the installation.                                 │
│                                                                [default: None]                                             │
│ --help                                                         Show this message and exit.                                 │
╰────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────╯
```


## Examples

See the [examples](examples) directory.


## License

Distributed under the MIT License. See the [LICENSE.md](LICENSE.md) for details.
