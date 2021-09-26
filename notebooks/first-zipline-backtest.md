---
jupyter:
  jupytext:
    text_representation:
      extension: .md
      format_name: markdown
      format_version: '1.3'
      jupytext_version: 1.11.2
  kernelspec:
    display_name: Python 3
    language: python
    name: python3
---

```python
import os

os.environ["QUANDL_API_KEY"] = "<my-api-key>"
```

```python
!zipline ingest -b quandl
```

```python
# Import Zipline functions that we need
from zipline import run_algorithm
from zipline.api import order_target_percent, symbol

import pandas as pd
import pytz
import altair as alt

def initialize(context):
    # Which stock to trade
    context.stock = symbol('AAPL')

    # Moving average window
    context.index_average_window = 100

def handle_data(context, data):
    # Request history for the stock
    equities_hist = data.history(context.stock, "close",
                                 context.index_average_window, "1d")

    # Check if price is above moving average
    if equities_hist[-1] > equities_hist.mean():
        stock_weight = 1.0
    else:
        stock_weight = 0.0

    # Place order
    order_target_percent(context.stock, stock_weight)


def analyze(context, perf):
    data = perf.resample("1w").mean().reset_index()
    first = alt.Chart(
        data,
        title="Equity Curve",
    ).mark_line().encode(
        x="index:T",
        y=alt.Y("portfolio_value", scale=alt.Scale(zero=False, type="log")),
        tooltip=["index", "portfolio_value"],
    ).properties(width=800, height=200)

    second = alt.Chart(
        data,
        title="Equity Curve",
    ).mark_line().encode(
        x="index:T",
        y="gross_leverage:Q",
        tooltip=["index", "gross_leverage"],
    ).properties(width=800, height=200)

    third = alt.Chart(
        data,
        title="Returns",
    ).mark_line().encode(
        x="index:T",
        y="returns:Q",
        tooltip=["index", "returns"],
    ).properties(width=800, height=200)
    alt.vconcat(first, second, third).display()

# Set start and end date
start_date = pd.Timestamp(year=1996, month=1, day=1, tzinfo=pytz.UTC)
end_date = pd.Timestamp(year=2018, month=12, day=31, tzinfo=pytz.UTC)

# Fire off the backtest
results = run_algorithm(
    start=start_date,
    end=end_date,
    initialize=initialize,
    analyze=analyze,
    handle_data=handle_data,
    capital_base=10000,
    data_frequency = 'daily', bundle='quandl'
)
```
