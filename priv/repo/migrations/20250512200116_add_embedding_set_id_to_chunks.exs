defmodule Exmeralda.Repo.Migrations.AddEmbeddingSetIdToChunks do
  use Ecto.Migration

  def up do
    alter table(:chunks) do
      add :embedding_set_id, references(:embedding_sets, on_delete: :delete_all, type: :binary_id)
    end

    execute """
    UPDATE chunks
    SET embedding_set_id = (
    SELECT library_embedding_sets.embedding_set_id
    FROM library_embedding_sets
    WHERE library_embedding_sets.library_id = chunks.library_id
    LIMIT 1
    )
    WHERE library_id IS NOT NULL;
    """
  end

  def down do
    alter table(:chunks) do
      remove :ingestion_id
    end
  end
end
