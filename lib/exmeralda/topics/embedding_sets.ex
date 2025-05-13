defmodule Exmeralda.Topics.EmbeddingSet do
  use Exmeralda.Schema

  alias Exmeralda.Topics.{Chunk, Library, LibraryEmbeddingSet}

  schema "embedding_sets" do
    field :state,
          Ecto.Enum,
          values: [:queued, :preprocessing, :chunking, :embedding, :failed, :ready],
          default: :queued

    timestamps()

    has_many :chunks, Chunk
    many_to_many :libraries, Library, join_through: LibraryEmbeddingSet
  end

  def changeset(embedding_set, attrs) do
    embedding_set
    |> cast(attrs, [:state])
    |> validate_required([:state])
  end
end
