'use strict';
module.exports = async function createStore({ memory, mongoUri }) {
  if (memory || !mongoUri) {
    const MemoryStore = require('./memory');
    return new MemoryStore();
  }
  const MongoStore = require('./mongo');
  const s = new MongoStore();
  await s.connect(mongoUri);
  return s;
};
