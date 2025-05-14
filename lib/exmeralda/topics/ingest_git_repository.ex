defmodule Exmeralda.Topics.IngestGitRepository do
  require Logger

  alias Exmeralda.Topics.{
    Library,
    EmbeddingSet,
    LibraryEmbeddingSet,
    Rag,
    Chunk,
    GenerateEmbeddingsWorker
  }

  alias Exmeralda.Repo

  @insert_batch_size 1000

  def ingest(path) do
    Logger.info("Processing Git repository at: #{path}")
    {library, embedding_set} = create_library_and_embedding_set(path)

    path
    |> preprocess_git_repository()
    |> insert_chunks(library, embedding_set)

    queue_embeddings_generation(library, embedding_set)

    :ok
  end

  defp queue_embeddings_generation(library, embedding_set) do
    GenerateEmbeddingsWorker.new(%{
      library_id: library.id,
      embedding_set_id: embedding_set.id
    })
    |> Oban.insert!()
  end

  defp preprocess_git_repository(path) do
    {:ok, chunks} = Rag.ingest_from_git_repository(path)
    chunks
  end

  defp insert_chunks(chunks, library, embedding_set) do
    chunks
    |> Enum.chunk_every(@insert_batch_size)
    |> Enum.each(fn batch ->
      batch_with_ids =
        Enum.map(batch, fn chunk ->
          chunk
          |> Map.put(:library_id, library.id)
          |> Map.put(:embedding_set_id, embedding_set.id)
        end)

      Repo.insert_all(Chunk, batch_with_ids)
    end)

    :ok
  end

  @doc """
  Creates a library with a name generated from the path, a version based on current time,
  links it to a new embedding set, and returns a tuple with {library, embedding_set}.
  """
  def create_library_and_embedding_set(path) do
    library = create_library(path)
    embedding_set = create_embedding_set()
    create_library_embedding_set(library, embedding_set)

    {library, embedding_set}
  end

  defp create_library_embedding_set(library, embedding_set) do
    %LibraryEmbeddingSet{}
    |> LibraryEmbeddingSet.changeset(%{
      library_id: library.id,
      embedding_set_id: embedding_set.id
    })
    |> Repo.insert!()
  end

  defp create_embedding_set do
    %EmbeddingSet{}
    |> EmbeddingSet.changeset(%{state: :queued})
    |> Repo.insert!()
  end

  defp create_library(path) do
    # Generate library name from path basename + current date in YYMMDD format
    date_str = Date.utc_today() |> Calendar.strftime("%y%m%d")
    basename = Path.basename(path) |> String.downcase() |> String.replace(~r/[^a-z0-9]/, "_")
    library_name = "local_#{basename}_#{date_str}"

    now = Time.utc_now()
    library_version = "#{now.hour}.#{now.minute}.#{now.second}"
    library_dependencies = []

    %Library{}
    |> Library.changeset(%{
      name: library_name,
      version: library_version,
      dependencies: library_dependencies
    })
    |> Repo.insert!()
  end

  @doc """
  Creates a new job for ingesting a Git repository from the given path.
  """
  def create_job(args) do
    %{path: path} = args
    Oban.Job.new(%{path: path}, worker: __MODULE__)
  end
end
