import './peg-0.10.0.js';

//const grammar_nquery = await Deno.readTextFile('./sql.pegjs')
const grammar1 = await Deno.readTextFile('./e.pegjs');

function parserGen() {
    const options = {
        output: "source",
    }
    try {
        const parser = peg.generate(grammar1, options);
        console.log("👍")
    } catch (e) {
        console.error(e)
    }
}
parserGen()

function debounce(time, f) {
    let inProgress = false;
    return () => {
        if (!inProgress) {
            inProgress = true;
            setTimeout(() => {
                f()
                inProgress = false;
            }, time)
        }
    }
}
const debouncedParseGen = debounce(1000, parserGen)
const watcher = Deno.watchFs('./e.pegjs')
for await (const event of watcher) {
    debouncedParseGen()
}


