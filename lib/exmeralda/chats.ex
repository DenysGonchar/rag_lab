defmodule Exmeralda.Chats do
  @moduledoc """
  The Chats context.
  """

  import Ecto.Query, warn: false
  alias Exmeralda.Repo
  alias Ecto.Multi
  alias Phoenix.PubSub

  alias Exmeralda.Topics.{Rag, Chunk}
  alias Exmeralda.Chats.{LLM, Message, Session, Source}

  @message_preload [:source_chunks]

  @doc """
  Returns the list of chat_sessions of a user.
  """
  def list_sessions(user) do
    user.id
    |> session_scope()
    |> order_by([s], desc: s.inserted_at)
    |> Repo.all()
  end

  @doc """
  Gets a single session of a user.
  """
  def get_session!(user, id) do
    user.id
    |> session_scope()
    |> Repo.get!(id)
    |> Repo.preload(messages: [@message_preload])
  end

  @doc """
  Gets a single message.
  """
  def get_message!(id) do
    Repo.get!(Message, id) |> Repo.preload(@message_preload)
  end

  defp session_scope(user_id) do
    from s in Session, where: s.user_id == ^user_id, preload: :library
  end

  @doc """
  Starts a session.
  """
  def start_session(user, attrs \\ %{}) do
    Multi.new()
    |> Multi.insert(:session, Session.create_changeset(%Session{user_id: user.id}, attrs))
    |> Multi.insert(:message, fn %{session: session} ->
      %Message{role: :user, content: session.prompt, index: 0, session: session}
    end)
    |> Multi.put(:previous_messages, [])
    |> assistant_message()
    |> Repo.transaction()
    |> case do
      {:ok, %{session: session, message: message, assistant_message: assistant_message}} ->
        {:ok, Map.put(session, :messages, [message, Map.put(assistant_message, :sources, [])])}

      {:error, :session, changeset, _} ->
        {:error, changeset}
    end
  end

  def continue_session(session, params) do
    Multi.new()
    |> Multi.put(:session, session)
    |> Multi.put(:previous_messages, all_messages(session))
    |> Multi.insert(:message, fn %{session: session} ->
      %Message{role: :user, session: session} |> Message.changeset(params)
    end)
    |> assistant_message()
    |> Repo.transaction()
    |> case do
      {:ok, %{message: message, assistant_message: assistant_message}} ->
        {:ok, [message, Map.put(assistant_message, :sources, [])]}

      {:error, :message, changeset, _} ->
        {:error, changeset}
    end
  end

  defp all_messages(%Session{id: session_id}) do
    from(m in Message,
      where: m.session_id == ^session_id,
      order_by: [asc: :index]
    )
    |> Repo.all()
  end

  defp assistant_message(multi) do
    multi
    |> Multi.insert(:assistant_message, fn %{session: session, message: message} ->
      %Message{
        role: :assistant,
        content: "",
        session: session,
        index: message.index + 1,
        incomplete: true
      }
    end)
    |> Multi.run(:request_generation, &request_generation/2)
  end

  defp request_generation(_, %{
         previous_messages: previous_messages,
         message: message,
         assistant_message: assistant_message,
         session: session
       }) do
    handler = %{
      on_llm_new_delta: fn _model, %LangChain.MessageDelta{} = data ->
        send_session_update(session, {:message_delta, assistant_message.id, data.content})
      end,
      on_message_processed: fn _chain, %LangChain.Message{} = data ->
        assistant_message =
          Repo.update!(
            assistant_message
            |> Message.changeset(%{incomplete: false, content: data.content})
          )
          |> Repo.preload(@message_preload)

        send_session_update(session, {:message_completed, assistant_message})
      end
    }

    Task.Supervisor.start_child(Exmeralda.TaskSupervisor, fn ->
      {chunks, generation} = build_generation(message, session.library_id)
      insert_sources(session, chunks, assistant_message)

      LLM.stream_responses(
        previous_messages ++ [%{message | content: generation.prompt}],
        handler
      )
    end)
  end

  defp build_generation(message, library_id) do
    scope = from c in Chunk, where: c.library_id == ^library_id

    Rag.build_generation(scope, message.content, ref: message)
  end

  defp insert_sources(session, chunks, assistant_message) do
    Repo.insert_all(
      Source,
      Enum.map(chunks, &%{chunk_id: &1.id, message_id: assistant_message.id})
    )

    send_session_update(session, {:sources, assistant_message.id})
  end

  defp send_session_update(session, payload) do
    PubSub.broadcast(
      Exmeralda.PubSub,
      "user-#{session.user_id}",
      {:session_update, session.id, payload}
    )
  end

  @doc """
  Deletes a session.
  """
  def delete_session(%Session{} = session) do
    Repo.delete(session)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking session changes.
  """
  def new_session_changeset(attrs \\ %{}) do
    Session.create_changeset(%Session{}, attrs)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for a new message.
  """
  def new_message_changeset(attrs \\ %{}) do
    Message.changeset(%Message{role: :user}, attrs)
  end
end
