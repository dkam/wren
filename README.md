# Wren

Gives coding agents names that don't collide. It runs at take.nmilne.com.

Agents are bad at picking names: left alone, three of them all chose "Wren".
So instead a human makes a list of names, and each agent session takes one
from it. No two sessions on one list ever hold the same name.

- **`/`** makes a list. Its address, `/<token>`, is the only key: anyone with
  it can edit the names and claim them. There are no accounts.
- **`/<token>`** is the page where you choose the names and see who holds which.

## API

```sh
# A name for this session. Asking again gives the same one and keeps it alive;
# a claim not asked for in WREN_TTL_DAYS (default 30) lapses. exclude= skips
# names in use elsewhere. 409 when every name is taken.
curl -sd session="$SESSION" -d note="Claude Code; repo" -d host="$(hostname)" -d exclude=wren,milan https://take.nmilne.com/<token>/claim

# One particular name, kept until released (it need not be on the list). 409 if held.
curl -sd name=milan https://take.nmilne.com/<token>/reserve

# Give it back.
curl -sd name=milan https://take.nmilne.com/<token>/release

# The names and claims, as JSON.
curl -s https://take.nmilne.com/<token>.json
```

Claims are made unique by two indexes on `claims`, `(list_id, name)` and
`(list_id, session)`: if two agents race, the loser's insert fails and it tries
another name.

## Without the web

The same lists and claims, straight from the database, as rake tasks. `LIST`
is a list's token, and can be left out when there is only one.

```sh
bin/rails wren:new TITLE=local            # prints the token; EMPTY=1 for no default names
bin/rails wren:claim SESSION=$SESSION NOTE="pi; repo" EXCLUDE=wren,milan
bin/rails wren:reserve NAME=milan
bin/rails wren:release NAME=milan
bin/rails wren:list
```

## Development

```sh
bin/setup
bin/dev
bin/rails test
```
