# grut

A hacky little regexp compiler, written for a talk at the
Yow! conference in Sydney 2016.  Try out with:
```
make
./grut /usr/share/dict/words
```
Features:
* Regexp style is backtracking.
* Supports *+.()?{} and literals.
* No support for [] or backslash escapes.
* No support for capturing brackets.

Known issues:
* Can't match a null character, and expects a null terminated string.
* Doesn't avoid zero length matches in loops, so it can hang on zero length loop bodies like (a?)* (see note 4 in section 15.10.2.5 of https://www.ecma-international.org/ecma-262/5.1/ )
* Counted loops inside loops won't count right.  Eg (ab+c)*
