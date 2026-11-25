// Easebuzz callback guards from the Prepzo P0 payment fixes. Razorpay verify
// and paid enrollment are covered by payments.service.test.js and
// courses.service.test.js.
const test = require('node:test');
const assert = require('node:assert');

const { PaymentTransaction } = require('../fees-payments/fees-payments.model');
const paymentsService = require('./payments.service');


test('handleEasebuzzResponse rejects a callback for an unknown order', async (t) => {
  t.mock.method(PaymentTransaction, 'findOne', () => ({ populate: async () => null }));
  const fulfil = t.mock.method(paymentsService, 'fulfillCourseEnrollment', async () => {});

  const res = await paymentsService.handleEasebuzzResponse({
    txnid: 'EB1', status: 'success', udf1: 'stu1', udf2: 'c1', amount: '1'
  });
  assert.strictEqual(res.success, false);
  assert.strictEqual(fulfil.mock.callCount(), 0);
});
