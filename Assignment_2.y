%{

/*	Definition section */
/*	insert the C library and variables you need */

#include <stdio.h>
#include <ctype.h>
#include <stdlib.h>
#include <string.h>
#include <stdbool.h>
#include <assert.h>

#define MAX_TYPE_LEN 8
#define MAX_ID_LEN 64
#define RESET "\033[0m"
#define RED "\033[31m"
#define GRN "\033[32m"

/* Symbol table's DS - linked list */
typedef struct __SYMBOL_ENTRY {
    char id[MAX_ID_LEN];
    char type[MAX_TYPE_LEN];
    void *data;
    struct __SYMBOL_ENTRY *pNext;
} entry;



int linenum = 0;    //init to 0 cuz the last line contains \n
int indx = 1;
char type[MAX_TYPE_LEN];
char id[MAX_ID_LEN];
bool created = false; // check if symbol table has been created
void *garbage[512]; //prepare for free()
int garbageIndex = 0;
bool workOnDouble = false; // to distinguish Arith on int or double

entry *pHead;

/*Extern variables that communicate with lex*/
extern int yylineno;
extern int yylex();

void yyerror(char *);


/*Symbol table function */
void Create_symbol();
void Insert_symbol(entry **, char *, char *);
bool Lookup_symbol(char *);
void Assign_symbol(char *, void *);
entry *getEntry(char *);
bool checkReDeclr(char *);
void Dump_symbol();
void printReverse(entry *);
void print(entry *);
void freeList(entry **);

/*The number of the symbol*/
int symnum;

%}

%code requires{
    typedef struct __TYPE_SELECTOR {
    int int_number;
    double db_number;
    int intArith;   //0: Not set 1: int 2:double
    } selector;
}
/* Token definition */
%token SEM PRINT WHILE INT DOUBLE LB RB
%token STRING ADD SUB MUL DIV
%token ASSIGN NUMBER FLOATNUM ID DCL

/*  Type definition:
    Define the type by %union{} to specify the type of token */
%union {
	selector * type_selector;
    char *str;
}

/* Type declaration : 
	Use %type to specify the type of token within < > 
	if the token or name of grammar rule will return value($$) 
*/
%type <str> DCL ID STRING
%type <type_selector> Factor Group Term Arith NUMBER FLOATNUM

%%

/* Define your parser grammar rule and the rule action */

lines: lines Stmt       
    |
    ;

// define statement type Declaration, Assign, Print, Arithmetic and Branch
Stmt: Decl SEM
    | Print SEM
    | Assign SEM
    | Arith SEM
    ;

Decl: DCL               {
                            sscanf($1, "%s %s", type, id);
                            if (!created) Create_symbol();
                            if (!checkReDeclr(id))
                                Insert_symbol(&pHead, type, id);
                        }
    | DCL ASSIGN Arith  {
                            sscanf($1, "%s %s", type, id);
                            //printf("%s / %s\n", type, id);
                            if (!created) Create_symbol();
                            if (!checkReDeclr(id)) {
                                Insert_symbol(&pHead, type, id);
                                if (Lookup_symbol(id))
                                    if (strcmp(type, "int") == 0) {
                                        if ($3->intArith == 1)
                                            Assign_symbol(id, &($3->int_number));
                                        else {
                                            int buf = (int)$3->db_number;
                                            Assign_symbol(id, &buf);
                                        }
                                    } else {
                                        if ($3->intArith == 1) {
                                            double dbuf = (double)$3->int_number;
                                            Assign_symbol(id, &dbuf); 
                                        } else
                                            Assign_symbol(id, &($3->db_number));
                                    }
                            }
                        }
    ;

Assign:
      ID ASSIGN Arith   {   //if ($3) printf("%p Arith = %d\n", $3, $3->int_number);
                            if (Lookup_symbol($1) && $3) {
                                printf("ASSIGN\n");
                                entry *target = getEntry($1);
                                if (strcmp(target->type, "int") == 0) {
                                    if ($3->intArith == 1)
                                        Assign_symbol($1, &($3->int_number));
                                    else {
                                        int buf = (int)$3->db_number;
                                        Assign_symbol($1, &buf);
                                    }
                                } else {
                                    if ($3->intArith == 1) {
                                        double dbuf = (double)$3->int_number;
                                        Assign_symbol($1, &dbuf);
                                    } else 
                                        Assign_symbol($1, &($3->db_number));
                                }
                            } else {}
                        }
    ;

Arith: 
      Term              {     
                            if ($1) {
                                //printf("$$: %p, Term: %d\n", $$, $1->int_number);
                                $$ = $1;
                            }
                            else 
                                $$ = NULL;
                        }
    | Arith ADD Term    { printf("Add\n");
                            //*$$ = *$1 + *$3;
                            if ($1->intArith == 2 && $3->intArith == 2) {
                                $$->db_number = $1->db_number + $3->db_number;
                                $$->intArith = 2;
                            } else if ($1->intArith == 2 && $3->intArith == 1) {
                                $$->db_number = $1->db_number + $1->int_number; // db + int = db
                                $$->intArith = 2;
                            } else if ($1->intArith == 1 && $3->intArith == 2) {
                                $$->db_number = $1->int_number + $3->db_number;
                                $$->intArith = 2;
                            } else {
                                $$->int_number = $1->int_number + $3->int_number;
                                $$->intArith = 1;
                            }
                        }
    | Arith SUB Term    { printf("Sub\n"); //*$$ = *$1 - *$3; 
                            if ($1->intArith == 2 && $3->intArith == 2) {
                                $$->db_number = $1->db_number - $3->db_number;
                                $$->intArith = 2;
                            } else if ($1->intArith == 2 && $3->intArith == 1) {
                                $$->db_number = $1->db_number - $1->int_number; // db + int = db
                                $$->intArith = 2;
                            } else if ($1->intArith == 1 && $3->intArith == 2) {
                                $$->db_number = $1->int_number - $3->db_number;
                                $$->intArith = 2;
                            } else {
                                $$->int_number = $1->int_number - $3->int_number;
                                $$->intArith = 1;
                            }
                        }
    ;

Term: Factor            {   if ($1 != NULL) {
                                $$ = $1;
                                //printf("$$: %p , Factor: %d\n", $$, $$->int_number);
                            } else
                                $$ = NULL;
                                //printf("nnn\n");
                        }
    | Term MUL Factor   {
                            if ($3 != NULL) {
                                printf("Mul\n");
                                //printf("%d %d\n", $1->intArith, $3->intArith);
                                if ($1->intArith == 2 && $3->intArith == 2) {
                                    $$->db_number = $1->db_number * $3->db_number;
                                    $$->intArith = 2;
                                } else if ($1->intArith == 2 && $3->intArith == 1) {
                                    $$->db_number = $1->db_number * $1->int_number; // db * int = db
                                    $$->intArith = 2;
                                } else if ($1->intArith == 1 && $3->intArith == 2) {
                                    $$->db_number = $1->int_number * $3->db_number;
                                    $$->intArith = 2;
                                } else {
                                    //printf("mul: %d %d\n", $1->int_number, $3->int_number);
                                    $$->int_number = $1->int_number * $3->int_number;
                                    $$->intArith = 1;
                                }

                            } else 
                                $$ = NULL;
                                //printf("nullllll\n");
                            
                        }
    | Term DIV Factor   {   
                            if (($3->intArith == 1 && $3->int_number == 0)
                                 || ( $3->intArith == 2 && $3->db_number == 0.0)) {
                                printf(RED "<ERROR> " RESET "The divsor can't be 0 " GRN "-- line %d\n" RESET
                                        , yylineno);
                                $$ = NULL;
                            } else {
                                printf("Div\n");
                                //*$$ = *$1 / (*$3);
                                if ($1->intArith == 2 && $3->intArith == 2) {
                                    $$->db_number = $1->db_number / $3->db_number;
                                    $$->intArith = 2;
                                } else if ($1->intArith == 2 && $3->intArith == 1) {
                                    $$->db_number = $1->db_number / $1->int_number; // db * int = db
                                    $$->intArith = 2;
                                } else if ($1->intArith == 1 && $3->intArith == 2) {
                                    $$->db_number = $1->int_number / $3->db_number;
                                    $$->intArith = 2;
                                } else {
                                    $$->int_number = $1->int_number / $3->int_number;
                                    $$->intArith = 1;
                                }
                            }
                        }
    ;

Factor:
      Group             { 
                            if ($$->intArith == 1) $$->int_number = $1->int_number;
                            else $$->db_number = $1->db_number;
                        }
    | NUMBER            { 
                            $$->intArith = 1;
                            $$->int_number = $1->int_number;
                            //printf("$$:%p, NUMBER: %d\n", $$, $1->int_number); 
                        }
    | FLOATNUM          { 
                            $$->intArith = 2;
                            $$->db_number = $1->db_number;
                        }
    | ID                {   //need modify
                            if (Lookup_symbol($1)) {
                                entry *target = getEntry($1);
                                if (target->data != NULL) {
                                    if (strcmp(target->type, "int") == 0) {
                                        $$->int_number = *((int *)target->data);
                                        $$->intArith = 1;
                                    } else {
                                        $$->db_number = *((double *)target->data);
                                        $$->intArith = 2;
                                    }
                                } else {
                                    printf(RED "<ERROR> " RESET "Variable %s uninitialize " GRN "-- line %d\n" RESET
                                            ,$1 ,yylineno);
                                    $$ = NULL;
                                }
                            } else
                                $$ = NULL;
                        }
    ;

Print: PRINT Group      { 
                            if($2) {
                                if ($2->intArith == 1) 
                                    printf("Print: %d\n", $2->int_number);
                                else
                                    printf("Print: %lf\n", $2->db_number);
                            }
                        }
    | PRINT LB STRING RB{ printf("Print: %s\n", $3); }
    ;

Group: LB Arith RB      {
                            if ($2) { 
                                $$ = malloc(sizeof(selector));
                                garbage[garbageIndex++] = $$;
                                assert(garbageIndex < 512 && "garbageIndex overflow");
                                //printf("$$:%p, Group: %d\n", $$, $2->int_number);
                                $$ = $2;
                            } else
                                $$ = NULL;
                        }
    ;
%%

int main(int argc, char** argv)
{
    yylineno = 1;
    symnum = 0;
    
    yyparse();

    for (int i = 0; i < garbageIndex; i++)
        free(garbage[i]);

	printf("\nTotal lines: %d \n",yylineno);
	Dump_symbol();
    return 0;
}

void yyerror(char *s) {
    printf("%s on %d line \n", s , yylineno);
}

void Create_symbol()
{
    printf("Create a symbol table\n");
    created = true;
}

void Insert_symbol(entry **headRef, char *t, char *id)
{
    printf("Insert a symbol: %s\n", id);

    /* Upper case to lower case */
    for (int i = 0; i < strlen(t); i++)
        if (*(t+i) < 97) *(t+i) += 32; 
    
    /* Push the new node to pHead */
    entry *newEntry = (entry *) malloc(sizeof(entry));
    newEntry->pNext = *headRef;
    *headRef = newEntry;

    strcpy(newEntry->id, id);
    strcpy(newEntry->type, t);
    newEntry->data = NULL;

    return;
}

bool Lookup_symbol(char* sym)
{
    entry *curr = pHead;

    while (curr != NULL) {
        //printf("sym = %s, id = %s\n", sym, curr->id);
        if (strcmp(sym, curr->id) == 0) 
            return true;
        curr = curr -> pNext;
    }
    
    if (pHead != NULL)
        printf(RED "<ERROR>" RESET " Can't find variable %s " GRN "-- line %d\n" RESET, sym, yylineno);

    if  (!created)
        printf(RED "<ERROR>" RESET " Symbol table NOT EXIST\n"); 
    return false;
}

void Assign_symbol(char *id, void *data)
{
    entry *curr = pHead;

    while (curr != NULL) {
        if (strcmp(id, curr->id) == 0) {
            if (strcmp(curr->type, "int") == 0) {
                /* First assignment -- need malloc */
                if (!curr->data) {
                    curr->data = (int *) malloc(sizeof(int));
                    assert(curr->data && "malloc error\n");
                }
                *((int *)curr->data) = *((int *)data);
            } else if (strcmp(curr->type, "double") == 0) {
                if (!curr->data) {
                    curr->data = (double *) malloc(sizeof(double));
                    assert(curr->data && "malloc error\n");
                }
                *((double *)curr->data) = *((double *)data);
            }
            
            return;
        }
        curr = curr -> pNext;
    }

    return;
}

entry *getEntry(char *id)
{
    entry *curr = pHead;

    while (curr != NULL) {
        if (strcmp(id, curr->id) == 0)
            return curr;
        curr = curr -> pNext;
    }

    return NULL;
}

bool checkReDeclr(char *id)
{
    entry *curr = pHead;

    while (curr != NULL) {
        if (strcmp(curr->id, id) == 0) {
            printf(RED "<ERROR>" RESET " Re-declaration for variable %s " GRN "-- line %d\n" RESET, id, yylineno);
            return true;
        }
        curr = curr -> pNext;
    }

    return false;
}

void Dump_symbol()
{
	printf("\nThe symbol table dump : \n");
    printf("No\tID\tType\tData\n");
    printReverse(pHead);
    freeList(&pHead);
}

void printReverse(entry *head)
{
    if (!head) {
        indx = 1;
        return;
    }
    printReverse(head->pNext);
    if (head->data != NULL) {
        if (strcmp(head->type, "int") == 0)
            printf("%d\t%s\t%s\t%d\n", indx++, head->id, head->type, *((int *)head->data));
        else
            printf("%d\t%s\t%s\t%lf\n", indx++, head->id, head->type, *((double *)head->data));
    } else
        printf("%d\t%s\t%s\n", indx++, head->id, head->type);
}

void print(entry *head)
{
    entry *curr = head;
    int count = 1;
    
    while (curr != NULL) {
        if (!curr->data)
            printf("%d \t %s \t %s \n", count++, curr->id, curr->type);
        else {
            if (strcmp(curr->type, "int") == 0) {
                printf("%d \t %s \t %s \t %d\n", count++, curr->id,
                                 curr->type, *((int *)curr->data));
            } else {
                printf("%d \t %s \t %s \t %lf\n", count++, curr->id,
                                 curr->type, *((double *)curr->data));
            }
        }
        curr = curr->pNext;
    }
    return;
}

void freeList(entry **headRef)
{
    entry *curr = *headRef;
    entry *next;

    while (curr != NULL) {
        next = curr -> pNext;
        if (curr->data) free(curr->data);
        free(curr);
        curr = next;
    }
    *headRef = NULL;
    return;
}
