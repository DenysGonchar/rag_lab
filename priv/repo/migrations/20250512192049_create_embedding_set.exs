defmodule Exmeralda.Repo.Migrations.CreateIngestionSet do
  use Ecto.Migration

  def change do
    execute(
      "CREATE TYPE embedding_set_state AS ENUM ('queued', 'preprocessing', 'chunking', 'embedding', 'failed', 'ready');",
      "DROP TYPE embedding_set_state"
    )

    create table(:embedding_sets) do
      add :state, :embedding_set_state, null: false
      timestamps(type: :utc_datetime_usec)
    end
  end
end
