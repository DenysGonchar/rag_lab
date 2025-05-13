defmodule Exmeralda.Topics.LibraryEmbeddingSet do
  use Exmeralda.Schema
  import Ecto.Changeset

  alias Exmeralda.Topics.{Library, EmbeddingSet}

  @primary_key false
  schema "library_embedding_sets" do
    belongs_to :library, Library
    belongs_to :embedding_set, EmbeddingSet

    timestamps(type: :utc_datetime_usec)
  end

  @doc false
  def changeset(library_embedding_set, attrs) do
    library_embedding_set
    |> cast(attrs, [:library_id, :embedding_set_id])
    |> validate_required([:library_id, :embedding_set_id])
  end
end
