defmodule Exmeralda.Topics.GenerateEmbeddingsWorker do
  use Oban.Worker, queue: :ingest, max_attempts: 20

  alias Exmeralda.Repo
  alias Exmeralda.Topics.{Chunk, Rag, EmbeddingSet, Library}

  import Ecto.Query

  @embeddings_batch_size 20
  @impl Oban.Worker
  def perform(%Oban.Job{
        args: %{
          "library_id" => library_id,
          "embedding_set_id" => embedding_set_id
        }
      }) do
    from(c in Chunk, where: c.embedding_set_id == ^embedding_set_id, select: c.id)
    |> Repo.all()
    |> Enum.chunk_every(@embeddings_batch_size)
    |> Enum.map(
      &__MODULE__.new(%{
        chunk_ids: &1,
        current_embedding_set_id: embedding_set_id,
        library_id: library_id
      })
    )
    |> Oban.insert_all()

    :ok
  end

  def perform(%Oban.Job{
        args: %{
          "chunk_ids" => chunk_ids,
          "current_embedding_set_id" => embedding_set_id,
          "library_id" => library_id
        }
      }) do
    from(c in Chunk, where: c.id in ^chunk_ids)
    |> Repo.all()
    |> Rag.generate_embeddings()
    |> Enum.map(&Chunk.set_embedding(Map.put(&1, :embedding, nil), &1.embedding))
    |> Enum.each(&Repo.update!/1)

    if all_embeddings_processed?(embedding_set_id) do
      Repo.get!(EmbeddingSet, embedding_set_id)
      |> EmbeddingSet.changeset(%{state: :ready})
      |> Repo.update!()

      library = Repo.get!(Library, library_id)
      current_embedding_set = Library.find_current_embedding_set(library)

      library
      |> Library.changeset(%{current_embedding_set_id: current_embedding_set.id})
      |> Repo.update!()
    end

    :ok
  end

  def all_embeddings_processed?(embedding_set_id) do
    from(c in Chunk, where: is_nil(c.embedding) and c.embedding_set_id == ^embedding_set_id)
    |> Repo.aggregate(:count) == 0
  end
end
