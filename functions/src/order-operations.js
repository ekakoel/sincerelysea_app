const crypto = require('node:crypto');
const admin = require('firebase-admin');
const { HttpsError } = require('firebase-functions/v2/https');

const OFFICIAL_STORE_ID = 'sincerelysea';
const OFFICIAL_STORE_NAME = 'SincerelySea Store';
const FULFILLMENT_MODE = 'admin_managed';
const TRUSTED_CHECKOUT_SOURCE = 'trusted_checkout';

function requiredText(value, field, maxLength) {
  const normalized = String(value || '').trim();
  if (!normalized || normalized.length > maxLength) {
    throw new HttpsError(
      'invalid-argument',
      `${field} is required and must be at most ${maxLength} characters.`,
    );
  }
  return normalized;
}

function normalizeCheckoutRequest(data) {
  const checkoutRequestId = requiredText(
    data?.checkoutRequestId,
    'checkoutRequestId',
    128,
  );
  if (!/^[A-Za-z0-9_-]{16,128}$/.test(checkoutRequestId)) {
    throw new HttpsError(
      'invalid-argument',
      'checkoutRequestId has an invalid format.',
    );
  }

  if (!Array.isArray(data?.items) || data.items.length === 0
      || data.items.length > 50) {
    throw new HttpsError(
      'invalid-argument',
      'Checkout must contain between 1 and 50 items.',
    );
  }

  const quantities = new Map();
  for (const item of data.items) {
    const productId = requiredText(item?.productId, 'productId', 150);
    const quantity = item?.quantity;
    if (!Number.isInteger(quantity) || quantity <= 0 || quantity > 99) {
      throw new HttpsError(
        'invalid-argument',
        'Each item quantity must be an integer between 1 and 99.',
      );
    }
    const combinedQuantity = (quantities.get(productId) || 0) + quantity;
    if (combinedQuantity > 99) {
      throw new HttpsError(
        'invalid-argument',
        'Combined quantity for one product cannot exceed 99.',
      );
    }
    quantities.set(productId, combinedQuantity);
  }

  return {
    checkoutRequestId,
    items: [...quantities.entries()]
      .map(([productId, quantity]) => ({ productId, quantity }))
      .sort((left, right) => left.productId.localeCompare(right.productId)),
    customerName: requiredText(data?.customerName, 'customerName', 100),
    phone: requiredText(data?.phone, 'phone', 32),
    address: requiredText(data?.address, 'address', 500),
  };
}

function orderIdFor(uid, checkoutRequestId) {
  const digest = crypto
    .createHash('sha256')
    .update(`${uid}\0${checkoutRequestId}`)
    .digest('hex');
  return `order_${digest.slice(0, 40)}`;
}

function authoritativeProduct(productId, product, quantity) {
  if (!product) {
    throw new HttpsError('not-found', `Product ${productId} was not found.`);
  }
  if (
    product.ownerType !== 'business'
    || product.ownerId !== OFFICIAL_STORE_ID
    || product.storeName !== OFFICIAL_STORE_NAME
    || product.managedByAdmins !== true
  ) {
    throw new HttpsError(
      'failed-precondition',
      `Product ${productId} is not an official-store product.`,
    );
  }
  if (product.availableForPurchase !== true) {
    throw new HttpsError(
      'failed-precondition',
      `Product ${productId} is unavailable.`,
    );
  }
  if (!['ready_stock', 'preorder'].includes(product.inventoryType)) {
    throw new HttpsError(
      'failed-precondition',
      `Product ${productId} has an invalid inventory type.`,
    );
  }
  if (typeof product.price !== 'number' || !Number.isFinite(product.price)
      || product.price < 0) {
    throw new HttpsError(
      'failed-precondition',
      `Product ${productId} has an invalid price.`,
    );
  }

  const productName = String(product.name || '').trim();
  if (!productName) {
    throw new HttpsError(
      'failed-precondition',
      `Product ${productId} has no name.`,
    );
  }

  const stock = product.stock;
  if (product.inventoryType === 'ready_stock') {
    if (!Number.isInteger(stock) || stock < quantity) {
      throw new HttpsError(
        'failed-precondition',
        `Insufficient stock for ${productName}.`,
      );
    }
  }

  const lineSubtotal = product.price * quantity;
  return {
    stock,
    lineSubtotal,
    snapshot: {
      productId,
      sellerId: String(product.userId || ''),
      productName,
      productImageUrl: Array.isArray(product.images)
        ? String(product.images.find((image) => String(image).trim()) || '')
        : '',
      inventoryType: product.inventoryType,
      preorderDays: Number.isInteger(product.preorderDays)
        && product.preorderDays >= 0 ? product.preorderDays : 0,
      quantity,
      price: product.price,
      lineSubtotal,
    },
  };
}

async function createCustomerOrder({
  db,
  uid,
  data,
  fieldValue = admin.firestore.FieldValue,
}) {
  if (!uid) {
    throw new HttpsError('unauthenticated', 'You must be signed in.');
  }
  const request = normalizeCheckoutRequest(data);
  const orderId = orderIdFor(uid, request.checkoutRequestId);
  const orderRef = db.collection('orders').doc(orderId);

  return db.runTransaction(async (tx) => {
    const existingOrder = await tx.get(orderRef);
    if (existingOrder.exists) {
      const existing = existingOrder.data();
      if (existing?.userId !== uid
          || existing?.checkoutRequestId !== request.checkoutRequestId) {
        throw new HttpsError('internal', 'Checkout identity conflict.');
      }
      return {
        orderId,
        totalPrice: existing.totalPrice,
        created: false,
      };
    }

    const productRefs = request.items.map((item) =>
      db.collection('products').doc(item.productId));
    const productDocs = await Promise.all(
      productRefs.map((reference) => tx.get(reference)),
    );

    const orderItems = [];
    let totalPrice = 0;
    for (let index = 0; index < request.items.length; index += 1) {
      const requestedItem = request.items[index];
      const product = productDocs[index].exists
        ? productDocs[index].data()
        : null;
      const authoritative = authoritativeProduct(
        requestedItem.productId,
        product,
        requestedItem.quantity,
      );
      orderItems.push(authoritative.snapshot);
      totalPrice += authoritative.lineSubtotal;

      if (authoritative.snapshot.inventoryType === 'ready_stock') {
        tx.update(productRefs[index], {
          stock: authoritative.stock - requestedItem.quantity,
        });
      }
    }

    tx.set(orderRef, {
      userId: uid,
      storeId: OFFICIAL_STORE_ID,
      storeName: OFFICIAL_STORE_NAME,
      items: orderItems,
      totalPrice,
      status: 'pending',
      createdAt: fieldValue.serverTimestamp(),
      updatedAt: fieldValue.serverTimestamp(),
      sellerIds: [],
      customerName: request.customerName,
      phone: request.phone,
      address: request.address,
      fulfillmentMode: FULFILLMENT_MODE,
      checkoutRequestId: request.checkoutRequestId,
      source: TRUSTED_CHECKOUT_SOURCE,
    });

    return { orderId, totalPrice, created: true };
  });
}

function restockItems(order) {
  if (!Array.isArray(order.items)) {
    throw new HttpsError('failed-precondition', 'Order items are invalid.');
  }
  const quantities = new Map();
  for (const item of order.items) {
    if (item?.inventoryType === 'preorder') continue;
    const productId = String(item?.productId || '').trim();
    const quantity = item?.quantity;
    if (!productId || !Number.isInteger(quantity) || quantity <= 0) {
      throw new HttpsError('failed-precondition', 'Order items are invalid.');
    }
    quantities.set(productId, (quantities.get(productId) || 0) + quantity);
  }
  return [...quantities.entries()].map(([productId, quantity]) => ({
    productId,
    quantity,
  }));
}

async function cancelCustomerOrder({
  db,
  uid,
  data,
  fieldValue = admin.firestore.FieldValue,
}) {
  if (!uid) {
    throw new HttpsError('unauthenticated', 'You must be signed in.');
  }
  const orderId = requiredText(data?.orderId, 'orderId', 150);
  const orderRef = db.collection('orders').doc(orderId);

  return db.runTransaction(async (tx) => {
    const orderDoc = await tx.get(orderRef);
    if (!orderDoc.exists) {
      throw new HttpsError('not-found', 'Order was not found.');
    }
    const order = orderDoc.data();
    if (order.userId !== uid) {
      throw new HttpsError(
        'permission-denied',
        'Only the buyer can cancel this order.',
      );
    }
    if (order.status === 'cancelled') {
      return { orderId, status: 'cancelled', alreadyCancelled: true };
    }
    if (order.status !== 'pending') {
      throw new HttpsError(
        'failed-precondition',
        'Only pending orders can be cancelled.',
      );
    }
    if (order.source !== TRUSTED_CHECKOUT_SOURCE) {
      throw new HttpsError(
        'failed-precondition',
        'This legacy order requires trusted operator review.',
      );
    }

    const items = restockItems(order);
    const productRefs = items.map((item) =>
      db.collection('products').doc(item.productId));
    const productDocs = await Promise.all(
      productRefs.map((reference) => tx.get(reference)),
    );
    for (let index = 0; index < items.length; index += 1) {
      if (!productDocs[index].exists) {
        throw new HttpsError(
          'failed-precondition',
          `Product ${items[index].productId} is unavailable for restock.`,
        );
      }
      const currentStock = productDocs[index].data()?.stock;
      if (!Number.isInteger(currentStock) || currentStock < 0) {
        throw new HttpsError(
          'failed-precondition',
          `Product ${items[index].productId} has invalid stock.`,
        );
      }
    }

    for (let index = 0; index < items.length; index += 1) {
      tx.update(productRefs[index], {
        stock: productDocs[index].data().stock + items[index].quantity,
      });
    }
    tx.update(orderRef, {
      status: 'cancelled',
      updatedAt: fieldValue.serverTimestamp(),
    });

    return { orderId, status: 'cancelled', alreadyCancelled: false };
  });
}

module.exports = {
  cancelCustomerOrder,
  createCustomerOrder,
  orderIdFor,
};
