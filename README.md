# Toretto

This is still work in progress(it fully works but could be greatly extended). I would love to get some help either graphics or code.

Toretto is an Elixir boilerplate for kick-starting your crypto bot project. It contains everything you need to immediately focus on writing algo instead of worrying about streaming and backoffice in general.

It's structured as umbrella app that consist of:
- `Hefty` - streaming backend supporting Binance, all done via supervision tree, resilient and prepared to shift data straight to your trading strategies
- `Ui` - Phoenix frontend to modify things using browser instead of raw queries to db. Things that
can be done via browser include: kicking off straming on symbol, modyfing naive strategy settings.

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

- implement backtesting routine (possibly CLI)
- implement naive trader algo
- dashboard screen to allow people to have strategies that flag "interesting" symbols (for example [volume trading](https://www.investopedia.com/articles/technical/02/010702.asp))
- possibly implement different exchanges to allow for strategies like [arbitrage](https://www.investopedia.com/terms/a/arbitrage.asp) and others.
