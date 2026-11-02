// The system monitor groups processes into apps by systemd unit (processes.js).
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { load } from './load.mjs';

const P = load('processes.js');
const user = '/user.slice/user-1000.slice/user@1000.service';

// A `top -b -n 2 -c` sample: rows are [pid, user, res KiB, cpu, command]; only the second
// iteration counts.
function top(rows) {
    const header = '    PID USER      PR  NI    VIRT    RES    SHR S  %CPU  %MEM     TIME+ COMMAND';
    const body = rows.map(([pid, owner, res, cpu, command]) =>
        `${String(pid).padStart(7)} ${owner.padEnd(8)}  20   0  100000 ${String(res).padStart(6)}  10000 S ${cpu.toFixed(1).padStart(5)}   0.1   0:01.00 ${command}`);
    return ['top - first', header, '      1 nobody    20   0       0      1      0 S 100.0   0.0   0:00.00 stale', '',
            'top - second', header, ...body].join('\n');
}
function cgroups(map) {
    return '\n## cgroups\n' + Object.entries(map).map(([pid, cg]) => `/proc/${pid}/cgroup:0::${cg}`).join('\n');
}
function byKey(groups) {
    return Object.fromEntries(groups.map(g => [g.key, g]));
}

test('an app scope is one app, with every process in it', () => {
    const g = byKey(P.group(top([
        [100, 'lia', 1000, 2.0, '/usr/lib/firefox/firefox'],
        [101, 'lia', 500, 1.0, '/usr/lib/firefox/firefox -contentproc'],
    ]), cgroups({ 100: `${user}/app.slice/app-firefox-100.scope`, 101: `${user}/app.slice/app-firefox-100.scope` })));
    const app = g['app-firefox-100.scope'];
    assert.deepEqual([...app.pids], ['100', '101']);
    assert.equal(app.cpu, 3);
    assert.equal(app.mem, 1500);
    assert.equal(app.appId, 'firefox');
    assert.deepEqual([...app.units], ['app-firefox-100.scope']);
    assert.equal(app.guarded, false);
});

test('scripts in a shared unit are not grouped by interpreter', () => {
    const shared = `${user}/app.slice/wayland-wm@hyprland.desktop.service`;
    const g = P.group(top([
        [200, 'lia', 100, 0.1, '/usr/bin/python3 /home/lia/.local/bin/penumbra-cast stream'],
        [201, 'lia', 100, 0.1, 'python3 -u /home/lia/.local/bin/penumbra-updates status'],
        [202, 'lia', 100, 0.1, 'bash /home/lia/.local/bin/penumbra-record'],
        [203, 'lia', 100, 0.1, 'kitty'],
        [204, 'lia', 100, 0.1, '/usr/bin/kitty --single-instance'],
    ]), cgroups({ 200: shared, 201: shared, 202: shared, 203: shared, 204: shared }));
    const names = [...g.map(x => x.name)].sort();
    assert.deepEqual(names, ['kitty', 'penumbra-cast', 'penumbra-record', 'penumbra-updates']);
    assert.equal(g.find(x => x.name === 'kitty').pids.length, 2);
    // Signalled by PID: the compositor's unit holds much more.
    assert.ok(g.every(x => x.units.length === 0));
});

test('the shell, the compositor and systemd cannot be ended', () => {
    const g = byKey(P.group(top([
        [300, 'lia', 300000, 3.0, '/usr/bin/quickshell -c penumbra'],
        [301, 'lia', 100, 0.0, 'bash -c something'],
        [302, 'lia', 50000, 1.0, 'Hyprland'],
        [303, 'lia', 9000, 0.0, '/usr/lib/systemd/systemd --user'],
    ]), cgroups({
        300: `${user}/app.slice/penumbra-shell.service`,
        301: `${user}/app.slice/penumbra-shell.service`,
        302: `${user}/app.slice/wayland-wm@hyprland.desktop.service`,
        303: `${user}/init.scope`,
    })));
    assert.equal(g['penumbra-shell.service'].guarded, true);
    assert.equal(g['penumbra-shell.service'].name, 'quickshell');
    assert.equal(g['Hyprland@wayland-wm@hyprland.desktop.service'].guarded, true);
    assert.equal(g['systemd@init.scope'].guarded, true);
});

test('scopes an app makes for its helpers join it; those the shell makes stay apart', () => {
    const g = byKey(P.group(top([
        [400, 'lia', 1000, 1.0, '/opt/Claude/claude-desktop'],
        [410, 'lia', 200, 1.0, '/opt/Claude/helper'],
        [500, 'lia', 300000, 1.0, '/usr/bin/quickshell -c penumbra'],
        [510, 'lia', 2000, 1.0, '/usr/bin/btop'],
    ]), cgroups({
        400: `${user}/app.slice/app-com.anthropic.Claude-400.scope`,
        410: `${user}/app.slice/run-p400-i7.scope`,
        500: `${user}/app.slice/penumbra-shell.service`,
        510: `${user}/app.slice/run-p500-i9.scope`,
    })));
    const claude = g['app-com.anthropic.Claude-400.scope'];
    assert.deepEqual([...claude.pids], ['400', '410']);
    assert.deepEqual([...claude.units], ['app-com.anthropic.Claude-400.scope', 'run-p400-i7.scope']);
    assert.equal(g['run-p400-i7.scope'], undefined);
    assert.ok(g['run-p500-i9.scope'], 'an app the shell started is its own');
    assert.equal(g['run-p500-i9.scope'].guarded, false);
});

test('kernel threads are one row, and the sampling itself is left out', () => {
    const g = byKey(P.group(top([
        [2, 'root', 0, 0.5, '[kthreadd]'],
        [3, 'root', 0, 0.5, '[rcu_gp]'],
        [600, 'lia', 4000, 1.0, 'bash -c LC_ALL=C top -b -n 2 -d 1 -w 512 -c -e k; echo'],
        [601, 'lia', 4000, 1.0, 'top -b -n 2 -d 1 -w 512 -c -e k'],
    ]), cgroups({})));
    assert.deepEqual(Object.keys(g), ['kernel']);
    assert.equal(g.kernel.cpu, 1);
});

test('top shortens wide memory figures', () => {
    assert.equal(P.kib('2048'), 2048);
    assert.equal(P.kib('1.5m'), 1536);
    assert.equal(P.kib('2.0g'), 2097152);
});

test('desktop file IDs come out of XDG unit names', () => {
    assert.equal(P.appId('app-firefox-1234.scope'), 'firefox');
    assert.equal(P.appId('app-com.anthropic.Claude-104022.scope'), 'com.anthropic.Claude');
    assert.equal(P.appId('app-nm\\x2dapplet@autostart.service'), 'nm-applet');
    assert.equal(P.appId('app-blueman@autostart.service'), 'blueman');
    assert.equal(P.appId('pipewire.service'), '');
});

test('helper scopes name the PID that made them', () => {
    assert.equal(P.parent('run-p104022-i99755.scope'), 104022);
    assert.equal(P.parent('kitty-121302-0.scope'), 121302);
    assert.equal(P.parent('app-code-oss-104726.scope'), 0);
    assert.equal(P.parent('penumbra-shell.service'), 0);
});
