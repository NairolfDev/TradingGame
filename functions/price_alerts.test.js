const test = require('node:test');
const assert = require('node:assert/strict');
const {evaluateAlert, processAlerts, buildMessage, MAX_ALERTS_PER_USER} = require('./price_alerts');

test('above/below trigger only on the right side of the threshold', () => {
  assert.equal(evaluateAlert({direction: 'above', price: 100}, 99.99).trigger, false);
  assert.equal(evaluateAlert({direction: 'above', price: 100}, 100).trigger, true);
  assert.equal(evaluateAlert({direction: 'below', price: 100}, 100.01).trigger, false);
  assert.equal(evaluateAlert({direction: 'below', price: 100}, 100).trigger, true);
});

test('a fired recurring alert re-arms only after the price crosses back', () => {
  const fired = {direction: 'above', price: 100, armed: false};
  assert.deepEqual(evaluateAlert(fired, 101), {trigger: false, armed: false});
  assert.deepEqual(evaluateAlert(fired, 100), {trigger: false, armed: false});
  assert.deepEqual(evaluateAlert(fired, 99), {trigger: false, armed: true});
  assert.deepEqual(evaluateAlert({direction: 'below', price: 50, armed: false}, 51), {trigger: false, armed: true});
});

test('message names the asset, price and direction in German', () => {
  const m = buildMessage({symbol: 'BTC', name: 'Bitcoin', direction: 'below', price: 60000}, 59000);
  assert.match(m.title, /Bitcoin/);
  assert.match(m.body, /unter/);
  assert.match(m.body, /59\.000/);
});

function fakeDb(alerts, tokens) {
  const updates = [];
  const deleted = [];
  const docs = alerts.map(({id, ...data}) => ({id, data: () => data, ref: {id, path: `priceAlerts/${id}`}}));
  const db = {
    updates, deleted,
    collection(name) {
      return {
        where(field, op, value) {
          return {
            async get() {
              if (name === 'priceAlerts') return {docs: docs.filter((d) => d.data().active === true)};
              return {docs: tokens.filter((t) => t.uid === value).map((t) => ({id: t.token}))};
            },
          };
        },
        doc: (id) => ({id, path: `${name}/${id}`}),
      };
    },
    batch() {
      const ops = [];
      return {
        update: (ref, data) => ops.push(['u', ref, data]),
        delete: (ref) => ops.push(['d', ref]),
        async commit() {
          for (const [kind, ref, data] of ops) (kind === 'u' ? updates.push([ref.id, data]) : deleted.push(ref.id));
        },
      };
    },
  };
  return db;
}

const fakeMessaging = (failTokens = []) => ({
  sent: [],
  async sendEachForMulticast(msg) {
    this.sent.push(msg);
    const responses = msg.tokens.map((t) => (failTokens.includes(t)
      ? {success: false, error: {code: 'messaging/registration-token-not-registered'}}
      : {success: true}));
    return {successCount: responses.filter((r) => r.success).length, responses};
  },
});

test('one-shot alert fires once, deactivates, and pushes to all devices of the owner', async () => {
  const db = fakeDb(
    [
      {id: 'a1', uid: 'u1', active: true, armed: true, direction: 'above', price: 100, recurring: false, yahooSymbol: 'X', symbol: 'X'},
      {id: 'a2', uid: 'u2', active: true, armed: true, direction: 'above', price: 200, recurring: false, yahooSymbol: 'X', symbol: 'X'},
    ],
    [{uid: 'u1', token: 't1'}, {uid: 'u1', token: 't2'}, {uid: 'u2', token: 't3'}],
  );
  const messaging = fakeMessaging();
  const stats = await processAlerts({db, messaging, getPrice: async () => 150, now: () => 1});
  assert.deepEqual(stats, {checked: 2, triggered: 1, sent: 2});
  assert.deepEqual(messaging.sent[0].tokens, ['t1', 't2']);
  assert.deepEqual(db.updates, [['a1', {active: false, armed: false, lastTriggeredAt: 1}]]);
});

test('recurring alert only disarms; dead tokens are removed', async () => {
  const db = fakeDb(
    [{id: 'r1', uid: 'u1', active: true, armed: true, direction: 'below', price: 10, recurring: true, yahooSymbol: 'Y', symbol: 'Y'}],
    [{uid: 'u1', token: 'good'}, {uid: 'u1', token: 'dead'}],
  );
  const stats = await processAlerts({db, messaging: fakeMessaging(['dead']), getPrice: async () => 9, now: () => 5});
  assert.equal(stats.sent, 1);
  assert.deepEqual(db.updates, [['r1', {armed: false, lastTriggeredAt: 5}]]);
  assert.deepEqual(db.deleted, ['dead']);
});

test('provider failure or invalid price never triggers or modifies alerts', async () => {
  const alerts = [{id: 'p1', uid: 'u1', active: true, armed: true, direction: 'above', price: 1, recurring: false, yahooSymbol: 'Z', symbol: 'Z'}];
  for (const getPrice of [async () => { throw new Error('down'); }, async () => null, async () => 0, async () => NaN]) {
    const db = fakeDb(alerts, [{uid: 'u1', token: 't'}]);
    const messaging = fakeMessaging();
    const stats = await processAlerts({db, messaging, getPrice});
    assert.deepEqual(stats, {checked: 0, triggered: 0, sent: 0});
    assert.equal(db.updates.length, 0);
    assert.equal(messaging.sent.length, 0);
  }
});

test('per-user cap limits how many alerts are evaluated', async () => {
  const alerts = Array.from({length: MAX_ALERTS_PER_USER + 5}, (_, i) => ({
    id: `c${i}`, uid: 'u1', active: true, armed: true, direction: 'above', price: 1000, recurring: false, yahooSymbol: 'Q', symbol: 'Q',
  }));
  const stats = await processAlerts({db: fakeDb(alerts, []), messaging: fakeMessaging(), getPrice: async () => 1});
  assert.equal(stats.checked, MAX_ALERTS_PER_USER);
});
