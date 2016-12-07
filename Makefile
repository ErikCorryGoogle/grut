all: grut.png

grut.dot: grut.dart
	dart grut.dart > grut.dot

grut.png: grut.dot
	dot -Gdpi=150 -T png -o grut.png grut.dot
	open grut.png
