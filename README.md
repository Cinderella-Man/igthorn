# Igthorn

[![Build Status](https://travis-ci.com/Frathon/Igthorn.svg?branch=1.0.0)](https://travis-ci.com/HedonSoftware/Igthorn)

Igthorn is a batteries-included cryptocurrency trading platform written in Elixir.

Non-comprehensive list of Igthorn's features:
- baked-in backtesting engine that allows to test your strategies against historical data
- "naive" trading strategy
- list and search through current and historical trades, orders and transactions
- view chart representations of your trading
and many others

Igthorn is a boilerplate for kick-starting your crypto trading project. It contains everything you
need to immediately focus on writing profitable algos instead of worrying about setup, custom framework etc.

It's structured as umbrella app that consist of:

- `Ui` - GUI - Phoenix frontend allows fine tuning of crypto trading environment using browser
instead of raw db queries. Things that can be done via browser include:
* starting/stoping straming on symbol,
* modyfing naive strategy settings
* starting/stoping trading
* starting backtesting
* and others.

- `Hefty` - Backend - streaming and trading backend supporting Binance consisting of:
* naive trading strategy
* backtesting engine
* business logic used by UI
* and others


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

Seeding script checks is there `api_key` and `secret` filled in config of Hefty. It will perform additional query to binance to fetch current assets' balances.

## Usage

After starting the server with `iex -S mix phx.server` it will automatically go to database and check
are there any symbols with enabled streaming and starts streaming for them.

User interface provides a way to start streaming `trade events` into db under the local url:
http://localhost:4000/streaming-settings

There's a column called "streaming" which contains true/false. By clicking on true/false in one of the rows you will flip(enable/disable) streaming for that symbol.

Here's a diagram of processes with 4 streams open:

![Hefty Supervision Tree](/docs/hefty_supervision_tree.png)

Enabling streaming will put data in Postgres database called `hefty_dev` in table `trade_events`.

## Dumping events

To get data out from database into csv file exs script can be used:

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
cd apps/hefty && MIX_ENV=backtesting mix ecto.reset && cd ../..
```

Step 2 - Import historical data

There's a CLI script that will download historical files for you. there's about 20 days of data
from June (2019-06-03 up to 2019-06-23). To load it you need to specify directory to store csv
dumps(script will download them for you) to as well as `from` and `to` dates and `symbol` that you are interested in - example below:

```
cd apps/hefty && MIX_ENV=backtesting mix run priv/repo/scripts/load-trade-events.exs --path="/backup/projects/binance-trade-events/" --from="2019-06-03" --to="2019-06-22" --symbol="XRPUSDT" && cd ../..
```

This will give you a little bit over 2.8 million events(20 days of trading data).

Step 3 - Start application in backtesting environment

```
MIX_ENV=backtesting iex -S mix phx.server
```

Step 4 - Enable trading on `XRPUSDT` pair - go to "Naive trader settings" and search for the symbol. Click on "Edit" set budget to some decent amount like 1000 and click "Save". Now click on "Disabled" button to enable trading. At this moment system will listen to XRPUSDT stream.

Step 5 - Now go to `Backtesting` section chose "XRPUSDT" symbol, select 2 dates (2019-06-03 and 2019-06-09) and click "Submit" which will send all 1 million events through naive strategy trader(s).

## Documentation

Hosted at [docs.igthorn.com](http://docs.igthorn.com)

To regenerate run:

```
mix docs
```
