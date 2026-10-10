.pragma library

// How well `query` matches `text` as a subsequence, ignoring case: higher is better, -1
// is no match. Letters that start a word or follow the previous match count most, and a
// match that starts early or contains the query whole gets a bonus.
function score(query, text) {
    if (query.length === 0)
        return 0;
    if (!text)
        return -1;
    const q = query.toLowerCase();
    const t = text.toLowerCase();

    let total = 0;
    let from = 0;
    let previous = -2;
    let first = -1;
    for (let i = 0; i < q.length; ++i) {
        // Take the first occurrence that directly follows the previous match or
        // starts a word, else the first occurrence.
        let at = -1;
        for (let j = t.indexOf(q[i], from); j !== -1; j = t.indexOf(q[i], j + 1)) {
            if (j === previous + 1 || isWordStart(text, j)) {
                at = j;
                break;
            }
            if (at === -1)
                at = j;
        }
        if (at === -1)
            return -1;
        if (at === previous + 1)
            total += 6;
        else if (isWordStart(text, at))
            total += 8;
        else
            total += 1;
        if (first === -1)
            first = at;
        previous = at;
        from = at + 1;
    }

    if (t.startsWith(q))
        total += 20;
    else if (t.includes(q))
        total += 10;
    return total - first * 0.5;
}

function isWordStart(text, i) {
    if (i === 0)
        return true;
    const before = text[i - 1];
    const here = text[i];
    return " -_./".includes(before) || (before === before.toLowerCase() && here !== here.toLowerCase());
}
