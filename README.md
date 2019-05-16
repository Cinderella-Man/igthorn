# Toretto

```
docker-compose up -d
mix deps.get
cd apps/ui/assets && npm install && cd ../../..
cd apps/hefty && mix ecto.reset && cd ../..

iex -S mix phx.server
```

Useful info:
`seeds` script will load all assets(currencies) and symbols(pairs) listed on binance to db.


Sample queries:

```
SELECT
    p.symbol,
    b1.asset AS "base asset",
    b1.free AS "base free",
    b1.locked AS "base locked",
    b2.asset AS "quote asset",
    b2.free AS "quote free",
    b2.locked AS "quote locked"
FROM pairs AS p
JOIN
    balances AS b1 ON p.base_asset_id = b1.id
JOIN
    balances AS b2 ON p.quote_asset_id = b2.id;
```