{
  var reservedMap = {};

  function debug(str){
    console.log(str);
  }

  function createUnaryExpr(op, e) {
    return {
      type     : 'unary_expr',
      operator : op,
      expr     : e
    }
  }

  function createBinaryExpr(op, left, right) {
    return {
      type      : 'binary_expr',
      operator  : op,
      left      : left,
      right     : right
    }  
  }

  function createList(head, tail) {
    var result = [head];
    for (var i = 0; i < tail.length; i++) {
      result.push(tail[i][3]);
    }
    return result;
  }

  function createExprList(head, tail, room) {
    var epList = createList(head, tail);
    var exprList  = [];
    var ep;
    for (var i = 0; i < epList.length; i++) {
      ep = epList[i]; 
      //the ep has already added to the global params
      if (ep.type == 'param') {
        ep.room = room;
        ep.pos  = i;
      } else {
        exprList.push(ep);  
      }
    }
    return exprList;
  }

  function createBinaryExprChain(head, tail) {
    var result = head;
    for (var i = 0; i < tail.length; i++) {
      result = createBinaryExpr(tail[i][1], result, tail[i][3]);
    }
    return result;
  }

  var cmpPrefixMap = {
    '+' : true,
    '-' : true,
    '*' : true,
    '/' : true,
    '>' : true,
    '<' : true,
    '!' : true,
    '=' : true,

    //between
    'B' : true,
    'b' : true,
    //for is or in
    'I' : true,
    'i' : true,
    //for like
    'L' : true,
    'l' : true,
    //for not
    'N' : true, 
    'n' : true, 
    //for contains
    'C' : true, 
    'c' : true, 
  }

  //used for store refered parmas
  var params = [];

  //used for dependency analysis
  var varList = [];
}

start 
  = where_clause

number
  = int_:int frac:frac exp:exp __ { return parseFloat(int_ + frac + exp); }
  / int_:int frac:frac __         { return parseFloat(int_ + frac);       }
  / int_:int exp:exp __           { return parseFloat(int_ + exp);        }
  / int_:int __                   { return parseFloat(int_);              }

int
  = digit19:digit19 digits:digits     { return digit19 + digits;       }
  / digit:digit
  / op:("-" / "+" ) digit19:digit19 digits:digits { return "-" + digit19 + digits; }
  / op:("-" / "+" ) digit:digit                   { return "-" + digit;            }

frac
  = "." digits:digits { return "." + digits; }

exp
  = e:e digits:digits { return e + digits; }

digits
  = digits:digit+ { return digits.join(""); }

digit   = [0-9]
digit19 = [1-9]

hexDigit
  = [0-9a-fA-F]

e
  = e:[eE] sign:[+-]? { return e + sign; }


single_char
  = [^'\\\0-\x1F\x7f]
  / escape_char

double_char
  = [^"\\\0-\x1F\x7f]
  / escape_char

escape_char
  = "\\'"  { return "'";  }
  / '\\"'  { return '"';  }
  / "\\\\" { return "\\"; }
  / "\\/"  { return "/";  }
  / "\\b"  { return "\b"; }
  / "\\f"  { return "\f"; }
  / "\\n"  { return "\n"; }
  / "\\r"  { return "\r"; }
  / "\\t"  { return "\t"; }
  / "\\u" h1:hexDigit h2:hexDigit h3:hexDigit h4:hexDigit {
      return String.fromCharCode(parseInt("0x" + h1 + h2 + h3 + h4));
    }

__ =
  whitespace*

char = .

whitespace =
  [ \t\n\r]

where_clause
    = __ e:expr __ { return e; }

expr = or_expr

or_expr
  = head:and_expr tail:(__ KW_OR __ and_expr)* {
      return createBinaryExprChain(head, tail);
    }

and_expr
  = head:not_expr tail:(__ KW_AND __ not_expr)* {
      return createBinaryExprChain(head, tail);
    }
//here we should use `NOT` instead of `comparision_expr` to support chain-expr
not_expr
  = (KW_NOT / "!" !"=") __ expr:not_expr {
      return createUnaryExpr('NOT', expr);
    }
  / LPAREN __ e:comparison_expr __ RPAREN { return e; }
  / comparison_expr

comparison_expr
  = left:additive_expr __ rh:comparison_op_right? {
      if (!rh) {
        return left;  
      } else {
        var res = null;
        if (rh.type == 'arithmetic') {
          res = createBinaryExprChain(left, rh.tail);
        } else {
          res = createBinaryExpr(rh.op, left, rh.right);
        }
        return res;
      }
    }
//optimization for comparison judge, bug because we in use `additive` expr
//in column clause now , it have little effect
cmp_prefix_char
  = c:char &{ return cmpPrefixMap[c]; }

comparison_op_right 
  = &cmp_prefix_char  body:(
      arithmetic_op_right
      / in_op_right
      / like_op_right
      / contains_op_right
    ){
      return body; 
    }
arithmetic_op_right
  = l:(__ arithmetic_comparison_operator __ additive_expr)+ {
      return {
        type : 'arithmetic',
        tail : l
      }
    } 

arithmetic_comparison_operator
  = ">=" / ">" / "<=" / "<>" / "<" / "=" / "!="  

in_op_right
  = op:in_op __ LPAREN  __ l:expr_list __ RPAREN {
      return {
        op    : op,  
        right : l
      }
    }
  / op:in_op __ e:var_decl {
      return {
        op    : op,  
        right : e
      }
    }


like_op
  = nk:(KW_NOT __ KW_LIKE) { return nk[0] + ' ' + nk[2]; }
  / KW_LIKE 

in_op 
  = nk:(KW_NOT __ KW_IN) { return nk[0] + ' ' + nk[2]; }
  / KW_IN

contains_op 
  = nk:(KW_NOT __ KW_CONTAINS) { return nk[0] + ' ' + nk[2]; }
  / KW_CONTAINS

like_op_right
  = op:like_op __ right:literal_string {
      return {
        op    : op,
        right : right
      }
    }

additive_expr
  = head:multiplicative_expr
    tail:(__ additive_operator  __ multiplicative_expr)* {
      return createBinaryExprChain(head, tail);
    }

additive_operator
  = "+" / "-"

multiplicative_expr
  = head:primary
    tail:(__ multiplicative_operator  __ primary)* {
      return createBinaryExprChain(head, tail)
    }

multiplicative_operator
  = "*" / "/" / "%"

primary 
  = literal
  / aggr_func
  / func_call 
  / column_ref 
  / param
  / LPAREN __ e:expr __ RPAREN { 
      e.paren = true; 
      return e; 
    } 
  / var_decl

literal 
  = literal_string / literal_numeric / literal_bool /literal_null

literal_list
  = head:literal tail:(__ COMMA __ literal)* {
      return createList(head, tail); 
    }

literal_null
  = KW_NULL {
      return {
        type  : 'null',
        value : null
      };  
    }

literal_bool 
  = KW_TRUE { 
      return {
        type  : 'bool',
        value : true
      };  
    }
  / KW_FALSE { 
      return {
        type  : 'bool',
        value : false
      };  
    }

literal_string 
  = ca:( ('"' double_char* '"') 
        /("'" single_char* "'")) {
      return {
        type  : 'string',
        value : ca[1].join('')
      }
    }
param 
  = l:(':' ident_name) { 
    var p = {
      type : 'param',
      value: l[1]
    } 
    //var key = 'L' + line + 'C' + column;
    //debug(key);
    //params[key] = p;
    params.push(p);
    return p;
  }

aggr_func
  = aggr_fun_count
  / aggr_fun_smma

aggr_fun_smma 
  = name:KW_SUM_MAX_MIN_AVG  __ LPAREN __ e:additive_expr __ RPAREN {
      return {
        type : 'aggr_func',
        name : name,
        args : {
          expr : e  
        } 
      }   
    }

KW_SUM_MAX_MIN_AVG
  = KW_SUM / KW_MAX / KW_MIN / KW_AVG 

aggr_fun_count 
  = name:KW_COUNT __ LPAREN __ arg:count_arg __ RPAREN {
      return {
        type : 'aggr_func',
        name : name,
        args : arg 
      }   
    }

count_arg 
  = e:star_expr {
      return {
        expr  : e 
      }
    }
  / __ c:column_ref {
      return {
        expr   : c
      }
    }

star_expr 
  = "*" {
      return {
        type  : 'star',
        value : '*'
      }
    }


func_call
  = name:ident __ LPAREN __ l:expr_list_or_empty __ RPAREN {
      return {
        type : 'function',
        name : name, 
        args : l
      }
    }
column_ref 
  = tbl:ident __ DOT __ col:column {
      return {
        type  : 'column_ref',
        table : tbl, 
        column : col
      }; 
    } 
  / col:column {
      return {
        type  : 'column_ref',
        table : '', 
        column: col
      };
    }

ident = 
  name:ident_name !{ return reservedMap[name.toUpperCase()] === true; } {
    return name;  
  }
  / '`' chars:[^`]+ '`' {
    return chars.join('');
  }

column = 
  name:column_name !{ return reservedMap[name.toUpperCase()] === true; } {
    return name;
  }
  / '`' chars:[^`]+ '`' {
    return chars.join('');
  }

column_name 
  =  start:ident_start parts:column_part* { return start + parts.join(''); }

literal_numeric
  = n:number {
      return {
        type  : 'number',
        value : n 
      }  
    }

ident_name  
  =  start:ident_start parts:ident_part* { return start + parts.join(''); }

ident_start = [A-Za-z_]
ident_part  = [A-Za-z0-9_]

//to support column name like `cf1:name` in hbase
column_part  = [A-Za-z0-9_:]

contains_op_right
  = op:contains_op __ LPAREN  __ l:expr_list __ RPAREN {
      return {
        op    : op,  
        right : l
      }
    }
  / op:contains_op __ e:var_decl {
      return {
        op    : op,  
        right : e
      }
    }

//for template auto fill
expr_list
  = head:expr tail:(__ COMMA __ expr)*{
      var el = {
        type : 'expr_list'  
      }
      var l = createExprList(head, tail, el); 

      el.value = l;
      return el;
    }

expr_list_or_empty
  = l:expr_list 
  / empty:expr_list { 
      return { 
        type  : 'expr_list',
        value : []
      }
    }

var_decl 
  = KW_VAR_PRE name:ident_name m:mem_chain {
    //push for analysis
    varList.push(name);
    return {
      type : 'var',
      name : name,
      members : m
    }
  }

mem_chain 
  = l:('.' ident_name)* {
    var s = [];
    for (var i = 0; i < l.length; i++) {
      s.push(l[i][1]); 
    }
    return s;
  }


KW_VAR_PRE = '$'

KW_NULL      = "NULL"i     !ident_start
KW_TRUE      = "TRUE"i     !ident_start
KW_FALSE     = "FALSE"i    !ident_start

KW_COUNT     = "COUNT"i    !ident_start    { return 'COUNT';    }
KW_MAX       = "MAX"i      !ident_start    { return 'MAX';      }
KW_MIN       = "MIN"i      !ident_start    { return 'MIN';      }
KW_SUM       = "SUM"i      !ident_start    { return 'SUM';      }
KW_AVG       = "AVG"i      !ident_start    { return 'AVG';      }
KW_LIKE      = "LIKE"i     !ident_start    { return 'LIKE';     }
KW_NOT       = "NOT"i      !ident_start    { return 'NOT';      }
KW_AND       = "AND"i      !ident_start    { return 'AND';      }
KW_OR        = "OR"i       !ident_start    { return 'OR';       }
KW_IN        = "IN"i       !ident_start    { return 'IN';       }
KW_CONTAINS  = "CONTAINS"i !ident_start    { return 'CONTAINS'; }
//specail character
DOT       = '.'
COMMA     = ','
STAR      = '*'
LPAREN    = '('
RPAREN    = ')'
