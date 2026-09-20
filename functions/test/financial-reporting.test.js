const assert = require('node:assert/strict');
const test = require('node:test');
const {
  recordOrderFinancialEvent,
} = require('../src/financial-reporting');

const fixedServerTime = new Date('2026-09-20T12:00:00.000Z');
const fieldValue = {
  increment: (amount) => ({ operation: 'increment', amount }),
  serverTimestamp: () => ({ operation: 'serverTimestamp' }),
};

function createMemoryFirestore() {
  const documents = new Map();

  return {
    documents,
    collection(collectionName) {
      return {
        doc(documentId) {
          return { path: `${collectionName}/${documentId}` };
        },
      };
    },
    async runTransaction(callback) {
      const transaction = {
        async get(reference) {
          const data = documents.get(reference.path);
          return {
            exists: data !== undefined,
            data: () => data,
          };
        },
        set(reference, data, options = {}) {
          const current = options.merge
            ? { ...(documents.get(reference.path) || {}) }
            : {};
          for (const [key, value] of Object.entries(data)) {
            if (value?.operation === 'increment') {
              current[key] = Number(current[key] || 0) + value.amount;
            } else if (value?.operation === 'serverTimestamp') {
              current[key] = fixedServerTime;
            } else {
              current[key] = value;
            }
          }
          documents.set(reference.path, current);
        },
      };
      return callback(transaction);
    },
  };
}

function officialOrder(totalPrice = 125) {
  return {
    storeId: 'sincerelysea',
    storeName: 'SincerelySea Store',
    totalPrice,
  };
}

test('order-created reporting uses a deterministic event and increments once', async () => {
  const db = createMemoryFirestore();
  const input = {
    db,
    orderId: 'order-1',
    order: officialOrder(),
    eventType: 'order_created',
    occurredAt: new Date('2026-09-20T01:00:00.000Z'),
    fieldValue,
  };

  assert.equal(await recordOrderFinancialEvent(input), true);
  assert.equal(await recordOrderFinancialEvent(input), false);
  assert.equal(db.documents.size, 2);
  assert.equal(
    db.documents.get('journal_entries/order_created_order-1').eventId,
    'order_created_order-1',
  );
  const report = db.documents.get('sales_reports/2026-09-20');
  assert.deepEqual(
    {
      orderCount: report.orderCount,
      grossSales: report.grossSales,
      netSales: report.netSales,
    },
    { orderCount: 1, grossSales: 125, netSales: 125 },
  );
});

test('order-cancelled reporting reverses the same order only once', async () => {
  const db = createMemoryFirestore();
  const baseInput = {
    db,
    orderId: 'order-1',
    order: officialOrder(),
    occurredAt: new Date('2026-09-20T01:00:00.000Z'),
    fieldValue,
  };

  await recordOrderFinancialEvent({
    ...baseInput,
    eventType: 'order_created',
  });
  assert.equal(await recordOrderFinancialEvent({
    ...baseInput,
    eventType: 'order_cancelled',
  }), true);
  assert.equal(await recordOrderFinancialEvent({
    ...baseInput,
    eventType: 'order_cancelled',
  }), false);

  assert.equal(
    db.documents.get('journal_entries/order_cancelled_order-1').eventId,
    'order_cancelled_order-1',
  );
  const report = db.documents.get('sales_reports/2026-09-20');
  assert.deepEqual(
    {
      cancelledOrderCount: report.cancelledOrderCount,
      grossSales: report.grossSales,
      cancelledSales: report.cancelledSales,
      netSales: report.netSales,
    },
    {
      cancelledOrderCount: 1,
      grossSales: 125,
      cancelledSales: 125,
      netSales: 0,
    },
  );
});
