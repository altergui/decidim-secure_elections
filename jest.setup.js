// jsdom does not expose `TextEncoder`/`TextDecoder` as globals, though every
// browser the voting page targets has had them for years (`link_code.js` uses
// them to pack and unpack the `?v=` link). Node has the same implementation, so
// lend it to the test environment rather than degrade the source to work around
// a gap that only exists here.
const { TextDecoder, TextEncoder } = require("node:util");

global.TextEncoder ||= TextEncoder;
global.TextDecoder ||= TextDecoder;
