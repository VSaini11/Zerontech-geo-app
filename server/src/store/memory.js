'use strict';
// In-memory store: used by tests and `npm run dev`. Same interface as the Mongo store.
class MemoryStore {
  constructor() {
    this.users = new Map();
    this.locations = new Map();
    this.events = new Map(); // eventId -> event
    this.seq = 1;
  }
  _id() { return String(this.seq++); }
  async findUserByName(name) { return [...this.users.values()].find((u) => u.name.toLowerCase() === String(name).toLowerCase()) || null; }
  async getUser(id) { return this.users.get(String(id)) || null; }
  async listUsers() { return [...this.users.values()]; }
  async createUser(u) { const id = this._id(); const doc = { id, tokenVersion: 0, currentStatus: 'checked_out', createdAt: Date.now(), ...u }; this.users.set(id, doc); return doc; }
  async updateUser(id, patch) { const u = this.users.get(String(id)); if (!u) return null; Object.assign(u, patch); return u; }
  async deleteUser(id) { return this.users.delete(String(id)); }
  async listLocations() { return [...this.locations.values()]; }
  async getLocation(id) { return this.locations.get(String(id)) || null; }
  async createLocation(l) { const id = this._id(); const doc = { id, assignedEmployees: [], radiusMeters: 100, ...l }; this.locations.set(id, doc); return doc; }
  async updateLocation(id, patch) { const l = this.locations.get(String(id)); if (!l) return null; Object.assign(l, patch); return l; }
  async deleteLocation(id) { return this.locations.delete(String(id)); }
  async insertEvents(list) {
    let inserted = 0;
    for (const e of list) if (!this.events.has(e.eventId)) { this.events.set(e.eventId, e); inserted++; }
    return inserted;
  }
  async listEvents(userName, from, to) {
    return [...this.events.values()].filter((e) => e.userName === userName && e.occurredAt >= from && e.occurredAt <= to);
  }
  // Adjustments may start before the window but still overlap it.
  async listAdjustments(userName, from, to) {
    return [...this.events.values()].filter((e) => e.userName === userName && e.type.startsWith('ADJ_') && e.occurredAt <= to && e.endAt >= from);
  }
  async deletePingsBefore(ts) {
    let n = 0;
    for (const [k, e] of this.events) if (e.type.startsWith('PING') && e.occurredAt < ts) { this.events.delete(k); n++; }
    return n;
  }
  async deleteEventsForUser(userName) { for (const [k, e] of this.events) if (e.userName === userName) this.events.delete(k); }
}
module.exports = MemoryStore;
