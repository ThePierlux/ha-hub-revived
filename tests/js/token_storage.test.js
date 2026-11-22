const fs = require("node:fs");
const path = require("node:path");
const test = require("node:test");
const assert = require("node:assert/strict");

const root = path.join(__dirname, "..", "..");
const manager = fs.readFileSync(path.join(root, "contents", "services", "HAManager.qml"), "utf8");
const mainQml = fs.readFileSync(path.join(root, "contents", "ui", "main.qml"), "utf8");

// Where the access token lives, and what may happen to it.
//
// The 1.3.1 manager kept the token in one place of its own - a shared LocalStorage
// database - and emptied the entry in the configuration as soon as that write had
// been acknowledged. In a QML applet on Plasma 6 the database never appears on
// disk, so the token lived only in memory: the widget connected until plasmashell
// restarted, and after that it had nothing to authenticate with, in the settings
// dialog as well as in the popup. A token a user has pasted is not transport for a
// store that does not exist. See the 2.1.0 notes.
//
// So: the configuration is the token's home, the shared database stays a copy
// another widget instance may read, and nothing is allowed to blank either.

test("the token is read from the configuration", () => {
    assert.match(
        manager,
        /property string accessToken:[^\n]*Plasmoid\.configuration\.accessToken/,
        "accessToken comes from the configuration, which is what survives a restart"
    );
});

test("the popup hands that token to the manager it builds", () => {
    assert.match(
        mainQml,
        /accessToken:\s*Plasmoid\.configuration\.accessToken/,
        "main.qml binds it, so the widget that starts with the shell authenticates"
    );
});

test("nothing empties the token, in the configuration or in the manager", () => {
    const offenders = [];
    const walk = (dir) => fs.readdirSync(dir, { withFileTypes: true }).flatMap((e) => {
        const p = path.join(dir, e.name);
        return e.isDirectory() ? walk(p) : (/\.(qml|js|mjs)$/.test(e.name) ? [p] : []);
    });

    for (const file of walk(path.join(root, "contents"))) {
        const lines = fs.readFileSync(file, "utf8").split("\n");
        lines.forEach((line, i) => {
            // An empty string (or nothing) assigned to either copy of the token:
            // the manager's own property, or the entry in the configuration.
            if (/\baccessToken\s*=\s*(?:""|''|null|undefined)\s*;/.test(line)
                || /configuration\.accessToken\s*=\s*(?:""|''|null|undefined)\s*;/.test(line)) {
                offenders.push(`${path.relative(root, file)}:${i + 1}: ${line.trim()}`);
            }
        });
    }

    assert.deepEqual(offenders, [], "a token that is wiped is a token the user has to paste again");
});
