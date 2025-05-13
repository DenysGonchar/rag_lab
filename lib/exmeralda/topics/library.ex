defmodule Exmeralda.Topics.Library do
  use Exmeralda.Schema
  import Ecto.Query

  alias Exmeralda.Topics.{Dependency, Chunk, EmbeddingSet, LibraryEmbeddingSet}
  alias Exmeralda.Repo

  @derive {Flop.Schema,
           filterable: [:name, :version],
           sortable: [:name, :version],
           default_limit: 20,
           max_limit: 100}

  schema "libraries" do
    field :name, :string
    field :version, :string
    embeds_many :dependencies, Dependency, on_replace: :delete

    has_many :chunks, Chunk
    many_to_many :embedding_sets, EmbeddingSet, join_through: LibraryEmbeddingSet
    belongs_to :current_embedding_set, EmbeddingSet, foreign_key: :current_embedding_set_id
    timestamps()
  end

  def find_current_embedding_set(library) do
    Repo.one!(
      from es in EmbeddingSet,
        join: les in LibraryEmbeddingSet,
        on: les.embedding_set_id == es.id,
        where: les.library_id == ^library.id,
        order_by: [
          fragment("case ? when 'ready' then 1 else 2 end", es.state),
          desc: es.inserted_at
        ],
        limit: 1
    )
  end

  @doc false
  def changeset(library, attrs) do
    library
    |> cast(attrs, [:name, :version, :current_embedding_set_id])
    |> validate_required([:name, :version])
    |> validate_format(:name, ~r/^[a-z][a-z0-9_]*?[a-z0-9]$/)
    |> validate_version()
    |> cast_embed(:dependencies)
    |> unique_constraint([:name, :version])
  end

  defp validate_version(changeset) do
    validate_change(changeset, :version, fn _, version ->
      case Version.parse(version) do
        {:ok, _} -> []
        :error -> [version: {"has invalid format", [validation: :version]}]
      end
    end)
  end
end
