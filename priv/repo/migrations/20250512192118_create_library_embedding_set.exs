defmodule Exmeralda.Repo.Migrations.CreateLibraryIngestionSet do
  use Ecto.Migration

  def up do
    create table(:library_embedding_sets, primary_key: false) do
      add :library_id, references(:libraries, on_delete: :delete_all, type: :binary_id)
      add :embedding_set_id, references(:embedding_sets, on_delete: :delete_all, type: :binary_id)

      timestamps(type: :utc_datetime_usec)
    end

    create index(:library_embedding_sets, [:library_id])
    create index(:library_embedding_sets, [:embedding_set_id])
    create unique_index(:library_embedding_sets, [:library_id, :embedding_set_id])

    # we are creating a new ingestion for each library. They are all the same.
    # no need to keep track of which is which. We assume that all libraries are
    # ready and none is still processing.
    execute """
    INSERT INTO embedding_sets (id, state, inserted_at, updated_at)
    SELECT
    gen_random_uuid(),
    'ready',
    NOW(),
    NOW()
    FROM libraries;
    """

    # Now we take libraries and ingestions without a counterpart and link them
    execute """
    INSERT INTO library_embedding_sets (library_id, embedding_set_id, inserted_at, updated_at)
    SELECT l.library_id, es.embedding_set_id, NOW(), NOW()
    FROM (
    SELECT l.id AS library_id, ROW_NUMBER() OVER (ORDER BY l.inserted_at) AS rn
    FROM libraries l
    LEFT JOIN library_embedding_sets li ON li.library_id = l.id
    WHERE li.library_id IS NULL
    ) l
    JOIN (
    SELECT es.id AS embedding_set_id, ROW_NUMBER() OVER (ORDER BY es.inserted_at) AS rn
    FROM embedding_sets es
    LEFT JOIN library_embedding_sets li ON li.embedding_set_id = es.id
    WHERE es.state = 'ready' AND li.embedding_set_id IS NULL
    ) es
    ON l.rn = es.rn;
    """
  end

  def down do
    drop table(:library_ingestions)
  end
end
