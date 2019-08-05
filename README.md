# Igthorn

[![Build Status](https://travis-ci.com/HedonSoftware/Igthorn.svg?branch=0.0.3)](https://travis-ci.com/HedonSoftware/Igthorn)

Igthorn is a batteries-included cryptocurrency trading environment written in Elixir.

It contains a lot more than just a trading bot, it allows you to do much more. Non-comprehensive list:
- naive strategy that trades based on assumption that price will have tendency to grow slowely
- backtesting engine that allows to test your strategies against historical data
- search and list current and historical orders and transactions
- view chart representations of your trading

Igthorn is a boilerplate for kick-starting your crypto bot project. It contains everything you need to immediately focus on writing algo instead of worrying about streaming and backoffice in general.

It's structured as umbrella app that consist of:
- `Ui` - GUI - Phoenix frontend to modify things using browser instead of raw queries to db. Things that
can be done via browser include: kicking off straming on symbol, modyfing naive strategy settings, starting trading, kicking of backtesting and others.
- `Hefty` - Backend - streaming backend supporting Binance, naive trading strategy and others


## Limit of Liability/Disclaimer of Warranty

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

## Setting up

```
docker-compose up -d
mix deps.get
cd apps/ui/assets && npm install && cd ../../..
cd apps/hefty && mix ecto.reset && cd ../..

iex -S mix phx.server
```

Seeding script checks is there `api_key` and `secret` filled in config of Hefty. It will perform additional query to binance to establish current balances.

## Usage

After starting the server with `iex -S mix phx.server` it will automatically go to database and check
are there any symbols with enabled streaming and potentially kick of streaming.

User interface provides a way to start streaming `trade events` into db under the local url:
http://localhost:4000/settings

There's a column called "streaming" which contains true/false. By clicking on true/false in one of the rows you will flip(enable/disable) streaming for that symbol.

Here's a diagram of processes with 4 streams open:

![Hefty Supervision Tree](/docs/hefty_supervision_tree.png)

So above will put data in Postgres database called `hefty_dev` in table
`trade_events`.

That's all nice and fine for algo trading but we need data for possibly back testing(this functionality will be added here soon - top of my todo list). To get data out from database into csv file exs script can be used:

```
cd apps/hefty
mix run priv/repo/scripts/dump-daily-trade-events.exs --date "2019-05-16"
```

This will create bunch of files in main directory of project (one for each symbol that it has any events in the day).

## Screenshots

![Seeding process](/docs/seeding.png)
![Settings screen](/docs/settings.png)
![Dashboard screen](/docs/dashboard.png)

## Naive trader strategy

Single strategy should be provided for
people to understand how to implement one on their own.

Naive strategy described in video called "[My Adventures in Automated Crypto Trading](https://youtu.be/b-8ciz6w9Xo?t=2257)" by Timothy Clayton

## Technical considerations:

- My aim is to keep UI close to Elixir with as minimal Javascript as possible so I definietly prefer to keep going on [Liveview](https://github.com/phoenixframework/phoenix_live_view) route.

- Would like to keep streaming seperate from trading as I would like to allow for multiple strategies running simultaneously. 

## To do:

- dashboard screen to allow people to have strategies that flag "interesting" symbols (for example [volume trading](https://www.investopedia.com/articles/technical/02/010702.asp))
- possibly implement different exchanges to allow for strategies like [arbitrage](https://www.investopedia.com/terms/a/arbitrage.asp) and others.

## Backtesting

Step 1 - Initialize empty database

```
export MIX_ENV=backtesting && cd apps/hefty && mix ecto.reset && cd ../..
```

Step 2 - Database needs to be filled with some data:

```
git clone https://github.com/Cinderella-Man/binance-trade-events.git /tmp/trade-events
gunzip /tmp/trade-events/dumps/XRPUSDT-2019-06-03.csv.gz
gunzip /tmp/trade-events/dumps/XRPUSDT-2019-06-04.csv.gz
gunzip /tmp/trade-events/dumps/XRPUSDT-2019-06-05.csv.gz
gunzip /tmp/trade-events/dumps/XRPUSDT-2019-06-06.csv.gz
gunzip /tmp/trade-events/dumps/XRPUSDT-2019-06-07.csv.gz
gunzip /tmp/trade-events/dumps/XRPUSDT-2019-06-08.csv.gz
gunzip /tmp/trade-events/dumps/XRPUSDT-2019-06-09.csv.gz
psql -Upostgres -h localhost -dhefty_backtesting  -c "\COPY trade_events FROM '/tmp/trade-events/dumps/XRPUSDT-2019-06-01.csv' WITH (FORMAT csv, delimiter ';');"
psql -Upostgres -h localhost -dhefty_backtesting  -c "\COPY trade_events FROM '/tmp/trade-events/dumps/XRPUSDT-2019-06-02.csv' WITH (FORMAT csv, delimiter ';');"
psql -Upostgres -h localhost -dhefty_backtesting  -c "\COPY trade_events FROM '/tmp/trade-events/dumps/XRPUSDT-2019-06-03.csv' WITH (FORMAT csv, delimiter ';');"
psql -Upostgres -h localhost -dhefty_backtesting  -c "\COPY trade_events FROM '/tmp/trade-events/dumps/XRPUSDT-2019-06-04.csv' WITH (FORMAT csv, delimiter ';');"
psql -Upostgres -h localhost -dhefty_backtesting  -c "\COPY trade_events FROM '/tmp/trade-events/dumps/XRPUSDT-2019-06-05.csv' WITH (FORMAT csv, delimiter ';');"
psql -Upostgres -h localhost -dhefty_backtesting  -c "\COPY trade_events FROM '/tmp/trade-events/dumps/XRPUSDT-2019-06-06.csv' WITH (FORMAT csv, delimiter ';');"
psql -Upostgres -h localhost -dhefty_backtesting  -c "\COPY trade_events FROM '/tmp/trade-events/dumps/XRPUSDT-2019-06-07.csv' WITH (FORMAT csv, delimiter ';');"
psql -Upostgres -h localhost -dhefty_backtesting  -c "\COPY trade_events FROM '/tmp/trade-events/dumps/XRPUSDT-2019-06-08.csv' WITH (FORMAT csv, delimiter ';');"
psql -Upostgres -h localhost -dhefty_backtesting  -c "\COPY trade_events FROM '/tmp/trade-events/dumps/XRPUSDT-2019-06-09.csv' WITH (FORMAT csv, delimiter ';');"
```

This will give you a little bit over 1 million events or one full week of trading data.

Step 3 - Start application in backtesting environment

```
export MIX_ENV=backtesting && iex -S mix phx.server
```

Step 4 - Enable trading on `XRPUSDT` pair - go to "Naive trader settings" and search for the symbol. Click on "Edit" set budget to some decent amount like 1000 and click "Save". Now click on "Disabled" button to enable trading. At this moment system will listen to XRPUSDT stream. 

Step 5 - 

Now go to `Backtesting` section chose "XRPUSDT" symbol, select 2 dates (2019-06-03 and 2019-06-09) and click "Submit" which will send all 1 million events through naive strategy trader(s).

## Documentation

Hosted at [docs.igthorn.com](http://docs.igthorn.com)

To regenerate run:

```
mix docs
```
