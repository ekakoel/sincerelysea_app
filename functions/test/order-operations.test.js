const assert = require('node:assert/strict');
const test = require('node:test');
const {
  cancelCustomerOrder,
  createCustomerOrder,
} = require('../src/order-operations');
const {
  recordOrderFinancialEvent,
} = require('../src/financial-reporting');

const fixedServerTime = new Date('2026-09-20T12:00:00.000Z');
const fieldValue = {
  increment: (amount) => ({ operation: 'increment', amount }),
  serverTimestamp: () => ({ operation: 'serverTimestamp' }),
};

function materialize(current, data) {
  const result = { ...current };
  for (const [key, value] of Object.entries(data)) {
    if (value?.operation === 'increment') {
      result[key] = Number(result[key] || 0) + value.amount;
    } else if (value?.operation === 'serverTimestamp') {
      result[key] = fixedServerTime;
    } else {
      result[key] = value;
    }
  }
  return result;
}

function createMemoryFirestore(seed = {}) {
  const documents = new Map(Object.entries(seed));
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
      const tx = {
        async get(reference) {
          const data = documents.get(reference.path);
          return { exists: data !== undefined, data: () => data };
        },
        set(reference, data, options = {}) {
          const current = options.merge
            ? documents.get(reference.path) || {}
            : {};
          documents.set(reference.path, materialize(current, data));
        },
        update(reference, data) {
          if (!documents.has(reference.path)) {
            throw new Error(`Missing document ${reference.path}`);
          }
          documents.set(
            reference.path,
            materialize(documents.get(reference.path), data),
          );
        },
      };
      return callback(tx);
    },
  };
}

function officialProduct(overrides = {}) {
  return {
    userId: 'catalog-admin',
    ownerType: 'business',
    ownerId: 'sincerelysea',
    storeName: 'SincerelySea Store',
    managedByAdmins: true,
    name: 'Authoritative Product',
    price: 125,
    inventoryType: 'ready_stock',
    preorderDays: 0,
    availableForPurchase: true,
    stock: 5,
    images: ['https://example.test/product.jpg'],
    ...overrides,
  };
}

function checkoutRequest(overrides = {}) {
  return {
    checkoutRequestId: 'checkout-request-0001',
    items: [{ productId: 'product-1', quantity: 2, price: 1 }],
    customerName: 'Customer',
    phone: '0800000000',
    address: 'Test address',
    totalPrice: 1,
    status: 'paid',
    ...overrides,
  };
}

function trustedOrder(overrides = {}) {
  return {
    userId: 'customer',
    storeId: 'sincerelysea',
    storeName: 'SincerelySea Store',
    fulfillmentMode: 'admin_managed',
    source: 'trusted_checkout',
    checkoutRequestId: 'checkout-request-0001',
    status: 'pending',
    totalPrice: 250,
    items: [{
      productId: 'product-1',
      inventoryType: 'ready_stock',
      quantity: 2,
      price: 125,
    }],
    ...overrides,
  };
}

async function rejectsWithCode(promise, code) {
  await assert.rejects(promise, (error) => error?.code === code);
}

test('trusted create rejects unauthenticated requests', async () => {
  const db = createMemoryFirestore();
  await rejectsWithCode(createCustomerOrder({
    db,
    uid: null,
    data: checkoutRequest(),
    fieldValue,
  }), 'unauthenticated');
});

test('trusted create uses authoritative values and is idempotent', async () => {
  const db = createMemoryFirestore({
    'products/product-1': officialProduct(),
    'products/product-2': officialProduct({
      name: 'Preorder Product',
      price: 50,
      inventoryType: 'preorder',
      stock: 0,
    }),
  });
  const input = {
    db,
    uid: 'customer',
    data: checkoutRequest({
      items: [
        { productId: 'product-1', quantity: 2, price: 1 },
        { productId: 'product-2', quantity: 1, price: 1 },
      ],
    }),
    fieldValue,
  };

  const first = await createCustomerOrder(input);
  const second = await createCustomerOrder(input);
  assert.deepEqual(first, { ...second, created: true });
  assert.equal(second.created, false);
  assert.equal(first.totalPrice, 300);

  const order = db.documents.get(`orders/${first.orderId}`);
  assert.equal(order.status, 'pending');
  assert.equal(order.source, 'trusted_checkout');
  assert.equal(order.totalPrice, 300);
  assert.equal(order.items[0].productName, 'Authoritative Product');
  assert.equal(order.items[0].price, 125);
  assert.equal(order.items[0].lineSubtotal, 250);
  assert.equal(order.items[1].price, 50);
  assert.equal(db.documents.get('products/product-1').stock, 3);
  assert.equal(db.documents.get('products/product-2').stock, 0);

  const financialInput = {
    db,
    orderId: first.orderId,
    order,
    eventType: 'order_created',
    occurredAt: fixedServerTime,
    fieldValue,
  };
  assert.equal(await recordOrderFinancialEvent(financialInput), true);
  assert.equal(await recordOrderFinancialEvent(financialInput), false);
  const report = db.documents.get('sales_reports/2026-09-20');
  assert.equal(report.orderCount, 1);
  assert.equal(report.grossSales, 300);
});

test('trusted create rejects invalid, unavailable, and insufficient products', async () => {
  await rejectsWithCode(createCustomerOrder({
    db: createMemoryFirestore(),
    uid: 'customer',
    data: checkoutRequest(),
    fieldValue,
  }), 'not-found');

  await rejectsWithCode(createCustomerOrder({
    db: createMemoryFirestore({
      'products/product-1': officialProduct({ availableForPurchase: false }),
    }),
    uid: 'customer',
    data: checkoutRequest(),
    fieldValue,
  }), 'failed-precondition');

  await rejectsWithCode(createCustomerOrder({
    db: createMemoryFirestore({
      'products/product-1': officialProduct({ stock: 1 }),
    }),
    uid: 'customer',
    data: checkoutRequest(),
    fieldValue,
  }), 'failed-precondition');
});

test('trusted cancellation restores stock once and is idempotent', async () => {
  const db = createMemoryFirestore({
    'orders/order-1': trustedOrder(),
    'products/product-1': officialProduct({ stock: 3 }),
  });
  const input = {
    db,
    uid: 'customer',
    data: { orderId: 'order-1' },
    fieldValue,
  };

  const first = await cancelCustomerOrder(input);
  const second = await cancelCustomerOrder(input);
  assert.equal(first.alreadyCancelled, false);
  assert.equal(second.alreadyCancelled, true);
  assert.equal(db.documents.get('orders/order-1').status, 'cancelled');
  assert.equal(db.documents.get('products/product-1').stock, 5);

  const financialInput = {
    db,
    orderId: 'order-1',
    order: db.documents.get('orders/order-1'),
    eventType: 'order_cancelled',
    occurredAt: fixedServerTime,
    fieldValue,
  };
  assert.equal(await recordOrderFinancialEvent(financialInput), true);
  assert.equal(await recordOrderFinancialEvent(financialInput), false);
  const report = db.documents.get('sales_reports/2026-09-20');
  assert.equal(report.cancelledOrderCount, 1);
  assert.equal(report.cancelledSales, 250);
});

test('trusted cancellation rejects non-owner and non-cancellable orders', async () => {
  const nonOwnerDb = createMemoryFirestore({
    'orders/order-1': trustedOrder(),
    'products/product-1': officialProduct({ stock: 3 }),
  });
  await rejectsWithCode(cancelCustomerOrder({
    db: nonOwnerDb,
    uid: 'attacker',
    data: { orderId: 'order-1' },
    fieldValue,
  }), 'permission-denied');
  assert.equal(nonOwnerDb.documents.get('products/product-1').stock, 3);

  const completedDb = createMemoryFirestore({
    'orders/order-1': trustedOrder({ status: 'completed' }),
    'products/product-1': officialProduct({ stock: 3 }),
  });
  await rejectsWithCode(cancelCustomerOrder({
    db: completedDb,
    uid: 'customer',
    data: { orderId: 'order-1' },
    fieldValue,
  }), 'failed-precondition');
  assert.equal(completedDb.documents.get('products/product-1').stock, 3);
});

test('trusted cancellation does not trust legacy order stock snapshots', async () => {
  const db = createMemoryFirestore({
    'orders/order-1': trustedOrder({ source: undefined }),
    'products/product-1': officialProduct({ stock: 3 }),
  });
  await rejectsWithCode(cancelCustomerOrder({
    db,
    uid: 'customer',
    data: { orderId: 'order-1' },
    fieldValue,
  }), 'failed-precondition');
  assert.equal(db.documents.get('products/product-1').stock, 3);
  assert.equal(db.documents.get('orders/order-1').status, 'pending');
});
