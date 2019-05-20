# fff-cr

Crystal port of dylanaraps/fff : "freakin fast file" manager written in bash.
I am just learning Crystal, so this project is just for learning.

Features:
- move between directories using arrow keys or h/l.
- open files with right arrow.
- select files and move or delete or yank
- detailed listing (v key) (not present in fff)

I have not ported everything.

Not ported:
- bulk rename
- image display -- can't install whatever it is, so can't run it
- pick key mappings from ENV
- some very bash specific stuff.
- open a shell
-

The original `fff` program link: https://github.com/dylanaraps/fff

## Installation

??? HOW TO INSTALL a CRYSTAL executable ?

- Copy files over or clone repo.
- crystal build src/fff.cr
- Copy fff to ~/bin or any other directory in PATH.
- Log file is written to ~/tmp/fff.log

## Usage

$  fff

## Status

Works.

## Development


## Contributing

1. Fork it (<https://github.com/mare-imbrium/fff/fork>)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## Contributors

- [kepler](https://github.com/mare-imbrium) - creator and maintainer
