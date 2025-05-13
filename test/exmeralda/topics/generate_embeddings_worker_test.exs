defmodule Exmeralda.Topics.GenerateEmbeddingsWorkerTest do
  use Exmeralda.DataCase
  import Ecto.Query
  alias Exmeralda.Topics.{GenerateEmbeddingsWorker, Chunk, EmbeddingSet, Library}
  alias Exmeralda.Repo

  def insert_library(_) do
    library = insert(:library)
    embedding_set = insert(:embedding_set)
    insert(:library_embedding_set, library: library, embedding_set: embedding_set)

    chunks =
      insert_list(25, :chunk, library: library, embedding: nil, embedding_set: embedding_set)

    %{chunks: chunks, library: library, embedding_set: embedding_set}
  end

  describe "perform/1" do
    setup [:insert_library]

    test "generates embeddings for a library", %{
      embedding_set: embedding_set,
      library: library,
      chunks: chunks
    } do
      assert :ok =
               perform_job(GenerateEmbeddingsWorker, %{
                 library_id: library.id,
                 embedding_set_id: embedding_set.id
               })

      workers = all_enqueued(worker: GenerateEmbeddingsWorker)

      chunk_ids = Enum.map(workers, & &1.args["chunk_ids"])

      [5, 20] = chunk_ids |> Enum.map(&length/1) |> Enum.sort()

      chunk_ids = List.flatten(chunk_ids)

      for c <- chunks do
        assert c.id in chunk_ids
      end

      assert from(c in Chunk, where: is_nil(c.embedding)) |> Repo.aggregate(:count) == 25

      %{success: 2} = Oban.drain_queue(queue: :ingest)

      refute from(c in Chunk, where: is_nil(c.embedding)) |> Repo.one()

      assert Repo.get!(EmbeddingSet, embedding_set.id).state == :ready
      assert Repo.get!(Library, library.id).current_embedding_set_id == embedding_set.id
    end
  end
end
