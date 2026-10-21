CREATE TABLE app_users (
  id UUID PRIMARY KEY,
  display_name VARCHAR(100) NOT NULL,
  email VARCHAR(190) NOT NULL UNIQUE,
  password_hash VARCHAR(255) NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE TABLE wallets (
  id UUID PRIMARY KEY,
  owner_id UUID NOT NULL REFERENCES app_users(id) ON DELETE CASCADE,
  name VARCHAR(80) NOT NULL,
  opening_balance NUMERIC(19,2) NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX idx_wallet_owner ON wallets(owner_id);
CREATE TABLE money_entries (
  id UUID PRIMARY KEY,
  owner_id UUID NOT NULL REFERENCES app_users(id) ON DELETE CASCADE,
  wallet_id UUID NOT NULL REFERENCES wallets(id) ON DELETE CASCADE,
  type VARCHAR(10) NOT NULL CHECK (type IN ('INCOME','EXPENSE')),
  category VARCHAR(50) NOT NULL,
  amount NUMERIC(19,2) NOT NULL CHECK (amount > 0),
  note VARCHAR(500),
  occurred_on DATE NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX idx_entries_owner_date ON money_entries(owner_id,occurred_on DESC);
CREATE TABLE budgets (
  id UUID PRIMARY KEY,
  owner_id UUID NOT NULL REFERENCES app_users(id) ON DELETE CASCADE,
  category VARCHAR(50) NOT NULL,
  month VARCHAR(7) NOT NULL,
  amount NUMERIC(19,2) NOT NULL CHECK (amount > 0),
  CONSTRAINT uq_budget_owner_category_month UNIQUE (owner_id,category,month)
);
CREATE INDEX idx_budgets_owner_month ON budgets(owner_id, month);
