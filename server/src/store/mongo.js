'use strict';
// MongoDB store. Reuses the existing `users` and `locations` collections (same field names as the
// old app) and adds one new collection, `geo_events`. Not exercised by the unit tests: they use
// MemoryStore. To move to Catalyst Data Store, implement this same interface on top of ZCQL.
const mongoose = require('mongoose');

const User = mongoose.model('User', new mongoose.Schema({}, { strict: false, collection: 'users' }));
const Location = mongoose.model('Location', new mongoose.Schema({}, { strict: false, collection: 'locations' }));
const GeoEvent = mongoose.model('GeoEvent', new mongoose.Schema({
  eventId: { type: String, unique: true, index: true },
  userName: { type: String, index: true },
  type: String,
  locationId: String,
  occurredAt: { type: Number, index: true },
  endAt: Number,
}, { strict: false, collection: 'geo_events' }));
GeoEvent.schema.index({ userName: 1, occurredAt: 1 });

const plain = (d) => {
  if (!d) return null;
  const o = d.toObject ? d.toObject() : d;
  o.id = String(o._id);
  delete o.__v;
  return o;
};

class MongoStore {
  async connect(uri) {
    await mongoose.connect(uri, { serverSelectionTimeoutMS: 15000 });
    await GeoEvent.init();
  }
  async findUserByName(name) {
    return plain(await User.findOne({ name: new RegExp('^' + String(name).replace(/[.*+?^${}()|[\]\\]/g, '\\$&') + '$', 'i') }));
  }
  async getUser(id) { try { return plain(await User.findById(id)); } catch { return null; } }
  async listUsers() { return (await User.find({})).map(plain); }
  async createUser(u) { return plain(await User.create({ tokenVersion: 0, currentStatus: 'checked_out', ...u })); }
  async updateUser(id, patch) { return plain(await User.findByIdAndUpdate(id, { $set: patch }, { new: true })); }
  async deleteUser(id) { return !!(await User.findByIdAndDelete(id)); }
  async listLocations() { return (await Location.find({})).map(plain); }
  async getLocation(id) { try { return plain(await Location.findById(id)); } catch { return null; } }
  async createLocation(l) { return plain(await Location.create({ assignedEmployees: [], radiusMeters: 100, ...l })); }
  async updateLocation(id, patch) { return plain(await Location.findByIdAndUpdate(id, { $set: patch }, { new: true })); }
  async deleteLocation(id) { return !!(await Location.findByIdAndDelete(id)); }
  async insertEvents(list) {
    if (!list.length) return 0;
    try {
      const r = await GeoEvent.insertMany(list, { ordered: false });
      return r.length;
    } catch (e) {
      // duplicate eventId (code 11000) is the normal "already delivered" case
      const ok = e.insertedDocs ? e.insertedDocs.length : (e.result && e.result.insertedCount) || 0;
      if (e.code === 11000 || (e.writeErrors && e.writeErrors.every((w) => w.code === 11000))) return ok;
      throw e;
    }
  }
  async listEvents(userName, from, to) {
    return (await GeoEvent.find({ userName, occurredAt: { $gte: from, $lte: to } }).lean()).map((e) => ({ ...e, id: String(e._id) }));
  }
  async listAdjustments(userName, from, to) {
    return (await GeoEvent.find({ userName, type: /^ADJ_/, occurredAt: { $lte: to }, endAt: { $gte: from } }).lean());
  }
  async deletePingsBefore(ts) { return (await GeoEvent.deleteMany({ type: /^PING/, occurredAt: { $lt: ts } })).deletedCount; }
  async deleteEventsForUser(userName) { await GeoEvent.deleteMany({ userName }); }
}
module.exports = MongoStore;
