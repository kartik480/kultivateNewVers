/**
 * Creates only the `todo_list` collection + index in database `kultitracker`.
 * Run once against Atlas or local MongoDB so the collection shows in Data Explorer.
 *
 * Atlas (replace URI; URL-encode password if needed):
 *   mongosh "mongodb+srv://USER:PASSWORD@CLUSTER.mongodb.net/?appName=kultitracker" --file mongodb/create_todo_list_collection.mongosh.js
 *
 * Local:
 *   mongosh "mongodb://127.0.0.1:27017" --file mongodb/create_todo_list_collection.mongosh.js
 */

const dbName = 'kultitracker';
const kultidb = db.getSiblingDB(dbName);

const existing = new Set(kultidb.getCollectionNames());
if (!existing.has('todo_list')) {
  kultidb.createCollection('todo_list');
  print('Created collection ' + dbName + '.todo_list');
} else {
  print('Collection todo_list already exists — skipped createCollection');
}

kultidb.todo_list.createIndex(
  { userId: 1, createdAt: -1 },
  { name: 'todo_list_user_created' }
);
print('Ensured index todo_list_user_created on ' + dbName + '.todo_list');
