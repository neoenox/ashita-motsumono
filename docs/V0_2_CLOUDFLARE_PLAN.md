# v0.2 Cloudflare同期計画

v0.1では実装しません。需要検証後に追加する想定です。

## 採用方針

- P2Pなし
- Cloudflare WorkersをAPI層にする
- Cloudflare D1を同期ハブにする
- 画像/PDFはまだ同期しない
- Todo、子ども、完了状態、期限、チェック項目だけ同期する

## 最小テーブル

```sql
CREATE TABLE families (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  deleted_at TEXT
);

CREATE TABLE users (
  id TEXT PRIMARY KEY,
  auth_provider TEXT NOT NULL,
  email_hash TEXT,
  display_name TEXT,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  deleted_at TEXT
);

CREATE TABLE family_members (
  id TEXT PRIMARY KEY,
  family_id TEXT NOT NULL,
  user_id TEXT NOT NULL,
  role TEXT NOT NULL,
  joined_at TEXT NOT NULL,
  deleted_at TEXT
);

CREATE TABLE cloud_children (
  id TEXT PRIMARY KEY,
  family_id TEXT NOT NULL,
  name TEXT NOT NULL,
  color INTEGER NOT NULL,
  sort_order INTEGER NOT NULL DEFAULT 0,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  deleted_at TEXT
);

CREATE TABLE cloud_todos (
  id TEXT PRIMARY KEY,
  family_id TEXT NOT NULL,
  child_id TEXT,
  title TEXT NOT NULL,
  due_date TEXT,
  category TEXT NOT NULL,
  amount INTEGER,
  note TEXT,
  status TEXT NOT NULL,
  created_by TEXT NOT NULL,
  updated_by TEXT NOT NULL,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  deleted_at TEXT
);

CREATE TABLE cloud_todo_items (
  id TEXT PRIMARY KEY,
  todo_id TEXT NOT NULL,
  label TEXT NOT NULL,
  is_checked INTEGER NOT NULL DEFAULT 0,
  sort_order INTEGER NOT NULL DEFAULT 0,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  deleted_at TEXT
);

CREATE INDEX idx_cloud_todos_family_due ON cloud_todos (family_id, due_date);
CREATE INDEX idx_cloud_todos_family_updated ON cloud_todos (family_id, updated_at);
CREATE INDEX idx_cloud_todo_items_todo ON cloud_todo_items (todo_id);
CREATE INDEX idx_family_members_user ON family_members (user_id);
```

## API案

- `POST /v1/families`
- `POST /v1/families/{familyId}/invites`
- `POST /v1/invites/join`
- `GET /v1/sync?family_id=...&since=...`
- `POST /v1/sync`

## 同期方式

- 端末内DBを主にする
- 変更をsync_queueへ積む
- 起動時/復帰時/手動更新時に差分同期
- 競合解決はv0.2ではLast Write Wins
