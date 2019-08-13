PGPASSWORD=postgres psql -Upostgres -h localhost -dhefty_backtesting  -c "\\copy (SELECT price, trade_time FROM trade_events ORDER BY trade_time ASC) TO '/tmp/prices.csv' (format csv, delimiter ';')"
