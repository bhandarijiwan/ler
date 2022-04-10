import './peg-0.10.0.js';

//const grammar_nquery = await Deno.readTextFile('./sql.pegjs')
const grammar = await Deno.readTextFile('./e.pegjs');


const options = {
    output: "source",
}

try {

    const parser = peg.generate(grammar, options);
} catch (e) {
    console.error(e)
}


