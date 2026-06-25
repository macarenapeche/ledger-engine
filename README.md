# ledger-engine

A double-entry accounting ledger as a Rails API. Money moves between accounts as
**balanced journal entries** — every transfer debits one account and credits another by
the same amount — and the invariant that *debits always equal credits* is enforced **in
Postgres itself**, not just in Ruby. So it holds even against a raw SQL writer, a buggy
service, or a concurrent request.

This is the part of fintech most CRUD apps get wrong: treating balances as a mutable
`accounts.balance` column you `+=` and `-=`. That column drifts, races, and can't be
audited. A ledger never stores a balance you mutate — it stores immutable entries and
*derives* the balance. This repo does it the real way.

## The model

| Concept | What it is |
|---|---|
| **Account** | Holds **one** currency. Has a `normal_balance` side: `debit` (assets) or `credit` (liabilities/equity). |
| **Journal entry** | One financial event. Has ≥2 postings that **sum to zero**. Immutable. |
| **Posting** | One leg of an entry: a `debit` or `credit` of a positive integer amount against an account. Immutable. |
| **Balance** | Never stored as truth — *derived* by summing an account's postings. |
| **Balance snapshot** | A cached balance pinned to a posting high-water mark, so derivation stays fast at scale. |

### Why "transfer A→B = debit A, credit B"

Customer wallets are modelled as **liabilities** (`normal_balance: credit`) — the platform
*owes* the customer their money. This is how neobanks actually keep books. Debiting a
liability *decreases* it (money leaves wallet A); crediting a liability *increases* it
(money arrives in wallet B). Platform-owned cash/bank accounts are **assets**
(`normal_balance: debit`).

### Money is integers

All amounts are **minor units** (cents) as `bigint`. No floats, ever. `100` EUR = `10000`.

### Multi-currency

**One account = one currency.** A single journal entry never mixes currencies — debits
can only equal credits within one unit. A holder who needs to hold EUR *and* USD gets
*two* accounts grouped by `holder_ref`. Cross-currency (FX) is modelled as two entries
through an FX position account, never a single "balanced" entry across currencies.

## The invariants (enforced in the database)

See [`db/migrate/20260625000004_add_ledger_invariants.rb`](db/migrate/20260625000004_add_ledger_invariants.rb):

1. **Balance** — a `DEFERRABLE INITIALLY DEFERRED` constraint trigger checks at *commit*
   that every touched journal entry has ≥2 postings, one currency, and `SUM(delta) = 0`
   (a posting's `delta` is a generated column: `+amount` for debits, `-amount` for credits).
   Deferred so both legs can be inserted before the check runs.
2. **Append-only audit trail** — `BEFORE UPDATE OR DELETE` triggers reject any mutation of
   `postings` / `journal_entries`. Corrections happen via *reversing entries*, never edits.
3. **Idempotency** — a unique index on `journal_entries.idempotency_key`; a replayed request
   returns the original entry instead of double-posting (race-safe via `RecordNotUnique`).
4. **Trial balance** — in a closed system the signed sum of *all* postings must be zero per
   currency. `GET /reconciliation` exposes it; `balanced: false` means money leaked.

Schema is dumped as SQL (`db/structure.sql`) so these triggers survive `db:schema:load`.

## API

```http
POST /transfers
Idempotency-Key: req_abc            # optional; retries are safe
{ "from": "wallet_1", "to": "wallet_2", "amount": 100, "currency": "EUR" }

POST /accounts                       # { external_id, holder_ref, name, currency, normal_balance }
GET  /accounts/:external_id
GET  /accounts/:external_id/balance
GET  /reconciliation                 # trial balance per currency
```

`amount` is in minor units. Internally a transfer becomes: **debit** the source wallet,
**credit** the destination, as one balanced journal entry.

## Code layout

```
app/models/            account, journal_entry, posting, balance_snapshot
app/operations/
  ledger/post_entry.rb        # THE primitive: writes a balanced entry, locks accounts, idempotent
  transfers/create.rb         # POST /transfers — debit source, credit destination
  balance_snapshots/capture.rb
  reconciliation.rb           # trial balance + snapshot verification
app/controllers/       transfers, accounts, reconciliation
db/migrate/            schema + the invariants migration
```

Every money movement — transfers, funding, fees, reversals — goes through the single
`Ledger::PostEntry` primitive. It's just a different set of `lines`.

## Running it

### Docker (one command)

Brings up Postgres + Redis + the Rails API + a Sidekiq worker. Runs the **production
image** (the same Dockerfile Kamal would deploy) over plain HTTP:

```bash
docker compose up --build
curl localhost:3000/reconciliation        # {"balanced":true,"trial_balance":{"EUR":0}}
curl localhost:3000/accounts/wallet_1_eur/balance
```

The web container runs `db:prepare` on boot (loads the schema incl. triggers, then seeds).

### Locally

Requires Ruby 3.4 and **PostgreSQL 16**.

```bash
bundle install
bin/rails db:create db:migrate db:seed
bin/rails server
bundle exec rspec          # 16 examples, incl. DB-level invariant proofs
```

> **Postgres tooling note:** if your `pg_dump` is newer than your server (e.g. libpq 17 in
> PATH but a 16 server), the SQL dump gets a `transaction_timeout` setting v16 can't read.
> Put the matching client first: `export PATH="/opt/homebrew/opt/postgresql@16/bin:$PATH"`.

## What the tests prove

- Balanced entries post and move both balances; unbalanced ones are rejected (in Ruby *and*
  by the DB trigger via `SET CONSTRAINTS ALL IMMEDIATE`).
- Postings/entries can't be updated or deleted, even through raw SQL.
- Idempotency keys replay instead of double-posting.
- Transfers refuse to overdraw a wallet (row-locked balance check).
- The trial balance nets to zero per currency; snapshots reconcile against later postings.

## Deliberately out of scope

FX rate handling, auth, pagination, and durable background snapshots (currently synchronous)
— the ledger core is the point. Snapshots would move to a job once posting volume warrants it.
