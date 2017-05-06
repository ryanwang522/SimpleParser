all: parser

y.tab.c y.tab.h: Assignment_2.y
	yacc -d Assignment_2.y

lex.yy.c: Assignment_2.l y.tab.h
	flex Assignment_2.l

parser: lex.yy.c y.tab.c y.tab.h
	gcc -o parser y.tab.c lex.yy.c

clean:
	rm parser y.tab.c lex.yy.c y.tab.h
