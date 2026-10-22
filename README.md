# Wren

Gives coding agents names that don't collide. It runs at wre.nmilne.com.

Agents are bad at picking names: left alone, three of them all chose "Wren".
So instead a human makes a key and chooses the names it gives out, and each
agent session is given one. No two sessions with one key ever hold the same name.

- **`/`** makes a key, or opens one you have. The key is the list's token, and
  its address is `/<token>`; anyone with it can change the list and claim
  names. There are no accounts.
- **`/<token>`** is the page where you choose the names and see who holds which.

## Choosing names

A list gives out the names in the first box on its page, **Your names**. A new
list has none, so gives out nothing until it has some.

Most come from the second box, **the catalog**: `config/names.txt`, shared by
every list, a line for each character, its name followed by its tags, as in
`hermione harry-potter hero female`. Characters can share a name, each on its
own line (`bill harry-potter male hero`, `bill doctor-who female`), and a name
matches tags when any one of its characters carries them all. Keep the file
sorted: `LC_ALL=C sort -o config/names.txt config/names.txt`. Click a name to
take it, or drag it across.
Search the catalog, or pick tags to narrow it to the names carrying every one,
and **Take all** takes all it shows: `james-bond villain male`, then
`harry-potter hero female`, gives Bond's male villains and Harry Potter's
female heroes. Names the catalog lacks can be typed in, and any name can be
taken out again with its ×.

A list takes copies, so to change the catalog, edit the file and deploy: each
list keeps the names it has.

## API

The key goes in an `Authorization: Bearer` header, so the address is the same
for every list and the key stays out of the request line. (A `key` field works
too, and so do `/<token>/claim`, `/<token>.json` and the rest; the logs mask a
key in a path.) `-d` sends a field as it is, which is fine for sessions and
names; a note is free text, so it goes with `--data-urlencode`, or a `+` or `&`
in it would be mangled.

```sh
# A name for this session. Asking again gives the same one and keeps it alive;
# a claim not asked for in WREN_TTL_DAYS (default 30) lapses. exclude= skips
# names in use elsewhere. 409 when every name is taken.
curl -s -H "Authorization: Bearer $WREN_KEY" -d session="$SESSION" --data-urlencode note="Claude Code; repo" -d host="$(hostname)" -d exclude=wren,milan https://wre.nmilne.com/claim

# One particular name, kept until released (it need not be on the list). 409 if held.
curl -s -H "Authorization: Bearer $WREN_KEY" -d name=milan https://wre.nmilne.com/reserve

# Give it back.
curl -s -H "Authorization: Bearer $WREN_KEY" -d name=milan https://wre.nmilne.com/release

# The names and the claims, as JSON.
curl -s -H "Authorization: Bearer $WREN_KEY" https://wre.nmilne.com/list
```

Claims are made unique by two indexes on `claims`, `(list_id, name)` and
`(list_id, session)`: if two agents race, the loser's insert fails and it tries
another name.

## Limits

A list holds at most 1000 names and 1000 claims; a title 100 characters, a
session 64, a note or host 200; a request body 64 KB, past which it gets a 413.
Each address may make 10 lists an hour, and 60 changes to names or 60 API calls
a minute, with the right key or a wrong one; past that it gets a 429.

## Without the web

The same lists and claims, straight from the database, as rake tasks. `LIST`
is a list's token, and can be left out when there is only one.

```sh
bin/rails wren:new TITLE=local TAGS=given-name    # prints the token
bin/rails wren:add NAMES="wren milan" TAGS="harry-potter female"   # TAGS as Take all does
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
