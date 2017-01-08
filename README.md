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
* Supports .()^$ and literals. Greedy and non-greedy ?*+{}, [] char classes.
* Supports look-aheads and look-behinds (variable length).
* Supports \b (word boundary).
* Supports back-references like \1.

Known issues:
* Can't match a null character, and expects a null terminated string.
* No Unicode support.
* Large input strings can overflow the stack when matching.
