import './peg-0.10.0.js';
import { parser } from './logical_expr_parser.js';

console.log(parser.parse("not(1)", { expressions: [false]}))

//const grammar_nquery = await Deno.readTextFile('./sql.pegjs')
const grammar1 = await Deno.readTextFile('./e.pegjs');


function parserGen() {
    const options = {
        // output: "source",
        // const parseResult = parser.parse('name = "john" and (svmxc__service_order__c.name = "hello" or name like "%hello%")')
    }
    try {
        const parser = peg.generate(grammar1, options);
        //const e  = "2 * (3 + 4)"
        const e = "not(1)"
        const parseResult = parser.parse(e, {
            expressions: [true, false]
        })
        console.log("Parse result", parseResult);
    } catch (e) {
        console.error(e)
    }
}
parserGen()
