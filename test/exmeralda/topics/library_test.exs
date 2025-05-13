defmodule Exmeralda.Topics.LibraryTest do
  use Exmeralda.DataCase

  alias Exmeralda.Topics.Library

  describe "constraints" do
    test "unique on name & version" do
      insert(:library, name: "ecto", version: "1.0.0")
      insert(:library, name: "ecto", version: "1.0.1")
      insert(:library, name: "phoenix", version: "1.0.1")

      assert_raise(Ecto.ConstraintError, ~r/libraries_name_version/, fn ->
        insert(:library, name: "phoenix", version: "1.0.1")
      end)
    end
  end

  describe "changeset/2" do
    test "casts embeds properly" do
      changeset =
        Library.changeset(%Library{}, %{
          name: "ecto",
          version: "1.0.0",
          dependencies: [
            %{
              name: "jason",
              version_requirement: "~> 1.0"
            },
            %{
              name: "telemetry",
              version_requirement: "~> 0.5 or ~> 1.0"
            }
          ]
        })
        |> assert_changes(:name, "ecto")
        |> assert_changes(:version, "1.0.0")
        |> assert_changes(:dependencies)

      assert [jason, _telementry] = changeset.changes[:dependencies]

      assert jason
             |> assert_changes(:name, "jason")
             |> assert_changes(:version_requirement, "~> 1.0")
    end

    test "validates names" do
      for name <- ~w(ecto phoenix_live_view absinthe_graphql my_lib123 nx) do
        assert Library.changeset(%Library{}, %{name: name, version: "1.0.0"}).valid?
      end

      for name <- ~w(_underscore_start 123numbersfirst s ends_with_ NOTEVENANAME $!@#) do
        cs = Library.changeset(%Library{}, %{name: name, version: "1.0.0"})
        refute cs.valid?
        assert_error_on(cs, :name, :format)
      end
    end

    test "validates version strings" do
      changeset =
        Library.changeset(%Library{}, %{
          name: "ecto",
          version: "xxx",
          dependencies: []
        })

      refute changeset.valid?
      assert_error_on(changeset, :version, :version)
    end

    test "validates version embeds" do
      changeset =
        Library.changeset(%Library{}, %{
          name: "ecto",
          version: "1.0.0",
          dependencies: [
            %{
              name: "telemetry",
              version_requirement: "xxx"
            }
          ]
        })

      refute changeset.valid?

      [telemetry] = changeset.changes[:dependencies]

      assert_error_on(telemetry, :version_requirement, :version_requirement)
    end
  end

  describe "find_current_embedding_set/1" do
    test "returns the most recent 'ready' embedding set if present, otherwise the most recent one" do
      library = insert(:library)
      # Insert a non-ready embedding set
      old_set = insert(:embedding_set, state: :chunking)
      insert(:library_embedding_set, library: library, embedding_set: old_set)
      # Insert a ready embedding set, but older
      ready_set_old = insert(:embedding_set, state: :ready, inserted_at: ~N[2023-01-01 00:00:00])
      insert(:library_embedding_set, library: library, embedding_set: ready_set_old)
      # Insert a newer ready embedding set
      ready_set_new = insert(:embedding_set, state: :ready, inserted_at: ~N[2023-02-01 00:00:00])
      insert(:library_embedding_set, library: library, embedding_set: ready_set_new)

      found = Library.find_current_embedding_set(library)
      assert found.id == ready_set_new.id

      # If no ready embedding set, returns the most recent one
      library2 = insert(:library)
      set1 = insert(:embedding_set, state: :chunking, inserted_at: ~N[2023-03-01 00:00:00])
      set2 = insert(:embedding_set, state: :embedding, inserted_at: ~N[2023-04-01 00:00:00])
      insert(:library_embedding_set, library: library2, embedding_set: set1)
      insert(:library_embedding_set, library: library2, embedding_set: set2)

      found2 = Library.find_current_embedding_set(library2)
      assert found2.id == set2.id
    end
  end
end
