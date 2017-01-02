# grut

A hacky regexp compiler that generates machine code for regexp matching,
originally written for a talk at the Yow! conference in Sydney 2016.  Requires
Dart language and Clang 3.8 or newer.  Try out with:
```
make all
./grut /usr/share/dict/words
```
Features:
* Regexp style is backtracking.
* Supports .()^$ and literals. Greedy and non-greedy ?*+{}, [] char classes and look-aheads.
* No support for \b (word boundary).
* No support for back-references or look-behinds.

Known issues:
* Can't match a null character, and expects a null terminated string.
* Doesn't avoid zero length matches in loops, so it can hang on zero length loop bodies like (a?)* (see note 4 in section 15.10.2.5 of https://www.ecma-international.org/ecma-262/5.1/ ).
* No Unicode support.
* Large input strings can overflow the stack when matching.
