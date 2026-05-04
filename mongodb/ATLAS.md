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

## 6. `todo_list` is empty in Atlas (but the app shows tasks)

The app **always** keeps a copy on the device. MongoDB is updated only when the **Node API** (`POST /api/todos` or `POST /api/todos/bootstrap`) runs against **the same** Atlas cluster your `.env` `MONGO_URI` points to.

1. **Spelling:** The database name must be **`kultitracker`** (with **t**). A typo like `kulitracker` is a different database; you will see an empty `todo_list` there.
2. **Wrong database in the URI:** If `MONGO_URI` has no path (or only `?`), the driver may use the default database **`test`**. In Atlas, open database **`test`** and look for collection **`todo_list`**. Fix the URI: `...mongodb.net/kultitracker?retryWrites=true&w=majority` (see repo `.env.example`).
3. **Hosted app vs local API:** In debug, Flutter uses the **production** API URL unless you pass `--dart-define=API_BASE_URL=...`. Data written by **Render** goes to whatever `MONGO_URI` is on **Render**, not necessarily the same as your laptop’s `node server.js` `.env`. Redeploy the backend with `routes/todos.js` and check **Render → Logs** for lines like `todo_list insert` or `todo_list bootstrap`.
4. **Not logged in:** Todos only sync with a **JWT** after login. Log in, then add a task or open Home so sync runs.
5. **Dev console:** Run the Flutter app and watch **Debug console** for `GET /api/todos/state` / `Todo bootstrap` / `add todo HTTP` — that shows whether the API is reachable and what HTTP status you get.
