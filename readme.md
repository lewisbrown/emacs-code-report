## Description

Emacs Code Report is something like a JavaDoc assembler, scanning given Emacs
files and developing an assemblage of various useful information in a
condensed, easily browsable form.

Currently, it scans for `require`, `provide`, `defgroup`, `defcustom`, `command`, 
`defun`, `defmacro`, `defadvice`, `defalias`, `define-key`, `set-key`, `set-chord`, 
forms and a `Commentary` section. For each form, the relevant parameters are listed 
as well as any doc string.

The output is formated in [org-mode](http://org-mode.org), a foldable, outline 
mode (to say the least) for Emacs.


## Usage

Simply list emacs files as arguments:

```zsh
emacs-code-report.pl elpa/**/*.el
```


or

```zsh
zargs -- prelude/**/*.el -- emacs-code-report.pl 
```

## Todo
- more comments
- error checking
- change so the script will recurse directories and find files itself
- refactor common code out of get_* functions
- should it have been written in elisp?

