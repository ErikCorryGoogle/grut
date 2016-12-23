all: grut.png grut.o grut

clean:
	rm -f grut.png grut.S grut.ll grut.o grutdriver.o grut

grut.dot: grut.dart
	dart grut.dart -d -e 'a.{2}z$$' > grut.dot

grut.png: grut.dot
	dot -Gdpi=150 -T png -o grut.png grut.dot
	#open grut.png

grut.ll: grut.dart
	dart grut.dart -l -e 'a.{2}z$$' > grut.ll

grut.S: grut.ll
	clang -O3 -S grut.ll

grut.o: grut.S
	clang -O3 -c grut.S

grutdriver.o: grut.cc
	clang++ -O3 -c -o grutdriver.o grut.cc

grut: grut.o grutdriver.o
	clang++ -O3 -o grut grut.o grutdriver.o
