defmodule Exmeralda.Accounts.User do
  use Exmeralda.Schema

  alias Exmeralda.Chats

  schema "users" do
    field :name, :string
    field :email, :string
    field :github_id, :string
    field :github_profile, :string
    field :avatar_url, :string
    field :terms_accepted_at, :utc_datetime_usec

    has_many :chats, Chats.Session

    timestamps()
  end

  @doc false
  def changeset(user, attrs) do
    user
    |> cast(attrs, [:name, :email, :github_id, :avatar_url, :github_profile])
    |> validate_required([:name, :email, :github_id, :avatar_url, :github_profile])
    |> validate_email(:email)
    |> validate_url(:avatar_url)
  end

  @doc false
  def email_changeset(user, attrs \\ %{}) do
    user
    |> cast(attrs, [:email])
    |> validate_required(:email)
    |> validate_email(:email)
  end

  @doc false
  def accept_terms_changeset(user) do
    change(user, terms_accepted_at: DateTime.utc_now())
  end
end
