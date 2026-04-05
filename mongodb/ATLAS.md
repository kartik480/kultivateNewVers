# See `kultitracker` on MongoDB Atlas

Atlas only lists a database after it exists **on that cluster**. If you never ran the init script (or your app) **against your Atlas connection string**, `kultitracker` will not appear.

## 1. Check you are in the right place

1. [cloud.mongodb.com](https://cloud.mongodb.com) → your **Project** → your **Cluster**.
2. Click **Browse Collections** (not only “Metrics”).
3. The database name appears in the **left sidebar** under the cluster.

## 2. Create `kultitracker` on Atlas (recommended)

1. Atlas → **Database** → **Connect** on your cluster.
2. Choose **Drivers** or **MongoDB Shell** and copy the URI. It looks like:
   `mongodb+srv://<user>:<password>@cluster0.xxxxx.mongodb.net/`
3. Install [mongosh](https://www.mongodb.com/try/download/shell) if needed.
4. **Encode your password** if it has `@`, `#`, etc. (e.g. `@` → `%40`).
5. From your project folder run (one line, replace USER, PASSWORD, CLUSTER):

```bash
mongosh "mongodb+srv://USER:PASSWORD@CLUSTER.mongodb.net/?appName=kultitracker" --file mongodb/init_indexes.mongosh.js
```

6. You should see: `Database "kultitracker" ready: collections + indexes applied.`
7. In Atlas, **refresh** Browse Collections — you should see database **kultitracker** and empty collections like `users`, `habits`, etc.

## 3. If it still does not show

- **Network Access**: Atlas → **Network Access** → allow your current IP (or `0.0.0.0/0` only for quick testing).
- **Database user**: Must exist and password must match the URI.
- **Wrong cluster**: Confirm the host in the URI matches the cluster you are viewing in the UI.
- **Delay**: Wait ~30 seconds and refresh Browse Collections.

## 4. Create it without mongosh (Atlas UI)

1. **Browse Collections** → **Create Database**.
2. Database name: `kultitracker`.
3. Collection name: `users` (or any name).
4. Create — then run `init_indexes.mongosh.js` against Atlas anyway so **indexes** are applied, or add indexes manually under each collection’s **Indexes** tab.

## 5. Why localhost did not help Atlas

Running the script against `mongodb://127.0.0.1:27017` only creates `kultitracker` on **your computer**, not on Atlas. Atlas is a **different server**; you must connect with the **`mongodb+srv://...`** string.
