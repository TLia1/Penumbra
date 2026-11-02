// load(name) → the functions of one of the shell's `.pragma library` scripts
// (config/quickshell/penumbra/NAME), run as plain JavaScript.
import fs from 'node:fs';
import path from 'node:path';
import vm from 'node:vm';

const shell = path.join(path.dirname(new URL(import.meta.url).pathname), '../../config/quickshell/penumbra');

export function load(name) {
    const source = fs.readFileSync(path.join(shell, name), 'utf8').replace(/^\.pragma library$/m, '');
    const context = vm.createContext({});
    vm.runInContext(source, context, { filename: name });
    return context;
}
