const test = require('node:test');
const assert = require('node:assert/strict');
const { supportContactSchema, updateConfigSchema } = require('./system-config.validation');

const ok = (v) => assert.equal(supportContactSchema.validate(v).error, undefined);
const bad = (v) => assert.ok(supportContactSchema.validate(v).error);

test('accepts valid and empty support contacts', () => {
  ok({ phone: '+919876543210', whatsapp: '9876543210', email: 'help@prepzo.com', website: 'https://prepzo.com' });
  ok({ phone: '', whatsapp: '', email: '', website: '' });
});

test('rejects malformed support contacts', () => {
  bad({ phone: '98765 abc' });
  bad({ phone: '1'.repeat(21) });
  bad({ email: 'not-an-email' });
  bad({ website: 'javascript:alert(1)' });
  bad({ website: 'ftp://prepzo.com' });
  bad({ unknown: 'x' });
});

test('updateConfigSchema validates nested supportContact', () => {
  assert.equal(updateConfigSchema.validate({ supportContact: { email: 'a@b.co' } }).error, undefined);
  assert.ok(updateConfigSchema.validate({ supportContact: { email: 'nope' } }).error);
});
