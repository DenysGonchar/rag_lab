# Exmeralda

## Prerequisits

- Erlang & Elixir
- Node JS
- Postgres (with [pgvector](https://github.com/pgvector/pgvector))

You can install all of it (except pgvector) with [asdf](https://github.com/asdf-vm/asdf).

To start PgSQL with pgvector:

```
docker run -p 5432:5432 --name some-postgres -e POSTGRES_PASSWORD=postgres -d pgvector/pgvector:pg17
```

To start your Phoenix server:

  * Run `mix setup` to install and setup dependencies
  * Start Phoenix endpoint with `mix phx.server` or inside IEx with `iex -S mix phx.server`

To test the chatbot locally you either need to start with a Groq API key (see 1password):

`GROQ_API_KEY=abcd JINA_API_KEY=abcd iex -S mix phx.server`

 or install Ollama:

```sh
brew install ollama
ollama pull llama3.2:latest
ollama pull unclemusclez/jina-embeddings-v2-base-code
```

and then start as usual:

```sh
mix setup
mix phx.server
```

or

```sh
mix setup
iex -S mix phx.server
```

Be aware that the seeded libraries are not that useful to chat with, since it is just dummy data.

Now you can visit [`localhost:4000`](http://localhost:4000) from your browser.
