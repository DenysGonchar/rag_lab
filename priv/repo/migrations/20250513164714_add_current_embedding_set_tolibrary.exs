defmodule Exmeralda.Repo.Migrations.AddCurrentEmbeddingSetTolibrary do
  use Ecto.Migration

  def up do
    alter table(:libraries) do
      add :current_embedding_set_id,
          references(:embedding_sets, on_delete: :nothing, type: :binary_id)
    end

    create index(:libraries, [:current_embedding_set_id])

    execute """
    UPDATE libraries
    SET current_embedding_set_id = (
      SELECT es.id
      FROM embedding_sets es
      JOIN library_embedding_sets les ON les.embedding_set_id = es.id
      WHERE les.library_id = libraries.id
      AND es.state = 'ready'
      ORDER BY es.inserted_at DESC
      LIMIT 1
    )
    WHERE current_embedding_set_id IS NULL;
    """
  end

  def down do
    alter table(:libraries) do
      remove :current_embedding_set_id
    end
  end
end
