Expression
  = head:AndExpression tail:(_ ("or") _ AndExpression)* {
      return tail.reduce(function(result, element, options) {
        if (element[1] === "or") { 
          return result || element[3]
        }
      }, head);
    }

AndExpression
  = head:NotExpression tail:(_ ("and") _ NotExpression)* {
      return tail.reduce(function(result, element) {
        if (element[1] === "and") {
          return result && element[3]
        }
      }, head);
    }

NotExpression
  = "not" _ head:NotExpression {
      console.log("came here")
      return !head
    }
  	/ Factor

Factor
  = "(" _ expr:Expression _ ")" { return expr; }
  / Integer

Integer "integer"
  = _ ('-')?[0-9]+ {
    const i = parseInt(text(), 10);
    if (i < 1) {
        throw new Error("indexes should start from 1")
    }
    if(!options.expressions) {
      throw new Error("expression was not passed")
    }
    if(i > options.expressions.length) {
      throw new Error(`Found ${i} but there are only ${options.expressions.length} expressions`)
    }
    return options.expressions[i-1]
  }

_ "whitespace"
  = [ \t\n\r]*