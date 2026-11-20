const assert = require('assert');
const rate = require('../../../quickshell/.config/quickshell/mizu/modules/mizu/bar/NetworkRate.js');
assert.strictEqual(rate.format(0), '0 B/s');
assert.strictEqual(rate.format(512), '512 B/s');
assert.strictEqual(rate.format(2048), '2 KB/s');
assert.strictEqual(rate.format(1572864), '1.5 MB/s');
assert.strictEqual(rate.format(-10), '0 B/s');
console.log('network rate formatting passed');
