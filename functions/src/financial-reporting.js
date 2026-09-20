const admin = require('firebase-admin');

const OFFICIAL_STORE_ID = 'sincerelysea';
const OFFICIAL_STORE_NAME = 'SincerelySea Store';

function reportKeyForDate(date) {
  const year = date.getUTCFullYear();
  const month = String(date.getUTCMonth() + 1).padStart(2, '0');
  const day = String(date.getUTCDate()).padStart(2, '0');
  return `${year}-${month}-${day}`;
}

function financialEventDefinition(eventType, totalPrice) {
  if (eventType === 'order_created') {
    return {
      memo: 'Customer order created for SincerelySea Store.',
      lines: [
        {
          accountCode: '1100',
          accountName: 'Accounts Receivable',
          debit: totalPrice,
          credit: 0,
        },
        {
          accountCode: '4100',
          accountName: 'Sales Revenue',
          debit: 0,
          credit: totalPrice,
        },
      ],
      reportChanges: {
        orderCount: 1,
        paidOrderCount: 0,
        completedOrderCount: 0,
        cancelledOrderCount: 0,
        grossSales: totalPrice,
        cancelledSales: 0,
        netSales: totalPrice,
      },
    };
  }

  if (eventType === 'order_cancelled') {
    return {
      memo: 'Order cancelled and reversed for SincerelySea Store.',
      lines: [
        {
          accountCode: '4190',
          accountName: 'Sales Returns',
          debit: totalPrice,
          credit: 0,
        },
        {
          accountCode: '1100',
          accountName: 'Accounts Receivable',
          debit: 0,
          credit: totalPrice,
        },
      ],
      reportChanges: {
        cancelledOrderCount: 1,
        cancelledSales: totalPrice,
        netSales: -totalPrice,
      },
    };
  }

  throw new Error(`Unsupported financial event type: ${eventType}`);
}

function validateOrder(orderId, order) {
  if (!orderId || typeof orderId !== 'string') {
    throw new Error('A Firestore order ID is required.');
  }
  if (!order || typeof order !== 'object') {
    throw new Error('The order snapshot is required.');
  }
  if (
    order.storeId !== OFFICIAL_STORE_ID
    || order.storeName !== OFFICIAL_STORE_NAME
  ) {
    throw new Error('Financial reporting accepts only SincerelySea Store orders.');
  }
  if (
    typeof order.totalPrice !== 'number'
    || !Number.isFinite(order.totalPrice)
    || order.totalPrice < 0
  ) {
    throw new Error('Order totalPrice must be a finite non-negative number.');
  }
}

async function recordOrderFinancialEvent({
  db,
  orderId,
  order,
  eventType,
  occurredAt,
  fieldValue = admin.firestore.FieldValue,
}) {
  validateOrder(orderId, order);
  if (!(occurredAt instanceof Date) || Number.isNaN(occurredAt.getTime())) {
    throw new Error('A valid server-observed event time is required.');
  }

  const definition = financialEventDefinition(eventType, order.totalPrice);
  const eventId = `${eventType}_${orderId}`;
  const reportDateKey = reportKeyForDate(occurredAt);
  const journalRef = db.collection('journal_entries').doc(eventId);
  const reportRef = db.collection('sales_reports').doc(reportDateKey);

  return db.runTransaction(async (tx) => {
    const existingJournal = await tx.get(journalRef);
    if (existingJournal.exists) {
      return false;
    }

    tx.set(journalRef, {
      storeId: OFFICIAL_STORE_ID,
      storeName: OFFICIAL_STORE_NAME,
      orderId,
      entryType: eventType,
      eventId,
      memo: definition.memo,
      lines: definition.lines,
      occurredAt,
      createdAt: fieldValue.serverTimestamp(),
      source: 'order_trigger',
    });

    const reportChanges = {};
    for (const [field, amount] of Object.entries(definition.reportChanges)) {
      reportChanges[field] = fieldValue.increment(amount);
    }
    tx.set(reportRef, {
      storeId: OFFICIAL_STORE_ID,
      storeName: OFFICIAL_STORE_NAME,
      reportDateKey,
      ...reportChanges,
      createdAt: fieldValue.serverTimestamp(),
      updatedAt: fieldValue.serverTimestamp(),
    }, { merge: true });

    return true;
  });
}

module.exports = {
  OFFICIAL_STORE_ID,
  OFFICIAL_STORE_NAME,
  recordOrderFinancialEvent,
  reportKeyForDate,
};
