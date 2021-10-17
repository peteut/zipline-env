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
import pathlib
import shutil
import os
import typing
from contextlib import closing
from selenium import webdriver
from selenium.webdriver import ChromeOptions
import tda
```

```python
api_key = "<my-api-key>"
redirect_uri = "<my-redirect-uri>"
token_path = pathlib.Path(os.curdir) / "token.json"
```

```python
def chrome(browser_name: str ="google-chrome-stable") -> typing.ContextManager[webdriver.Chrome]:
    opts = ChromeOptions()                            
    opts.binary_location = shutil.which(browser_name)
    return closing(webdriver.Chrome(options=opts))
```

# Fetching a Token

Refer to [tda-api/auth.html#fetching-a-token-and-creating-a-client](https://tda-api.readthedocs.io/en/latest/auth.html#fetching-a-token-and-creating-a-client) for details.

If you cannot use a browser you may use the `tda-generate-token.py` from the
console.

```python
with chrome() as driver:
    tda.auth.client_from_login_flow(driver, api_key, redirect_uri, token_path, redirect_wait_time_seconds=0.1, max_waits=3000)
```
