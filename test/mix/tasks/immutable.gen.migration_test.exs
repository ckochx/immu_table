defmodule Mix.Tasks.Immutable.Gen.MigrationTest do
  use ExUnit.Case, async: false

  import Mix.Tasks.Immutable.Gen.Migration, only: [run: 1]

  @tmp_path Path.expand("../../tmp", __DIR__)

  setup do
    File.rm_rf!(@tmp_path)
    File.mkdir_p!(@tmp_path)
    on_exit(fn -> File.rm_rf!(@tmp_path) end)
    :ok
  end

  describe "run/1" do
    test "generates a migration file with create_immutable_table" do
      in_tmp(fn ->
        run(["Blog.Post", "posts", "title:string", "body:text"])

        assert [migration_file] = Path.wildcard("priv/repo/migrations/*_create_posts.exs")

        assert_file(migration_file, fn content ->
          assert content =~ "defmodule MyApp.Repo.Migrations.CreatePosts do"
          assert content =~ "use Ecto.Migration"
          assert content =~ "import ImmuTable.Migration"
          assert content =~ "def change do"
          assert content =~ "create_immutable_table :posts do"
          assert content =~ "add :title, :string"
          assert content =~ "add :body, :text"
        end)
      end)
    end

    test "handles references with foreign key" do
      in_tmp(fn ->
        run(["Blog.Comment", "comments", "body:text", "post_id:references:posts"])

        assert [migration_file] = Path.wildcard("priv/repo/migrations/*_create_comments.exs")

        assert_file(migration_file, fn content ->
          assert content =~ "add :post_id, references(:posts, column: :entity_id, type: :uuid)"
        end)
      end)
    end

    test "handles various field types" do
      in_tmp(fn ->
        run([
          "Blog.Article",
          "articles",
          "title:string",
          "views:integer",
          "rating:float",
          "published:boolean",
          "published_at:utc_datetime"
        ])

        assert [migration_file] = Path.wildcard("priv/repo/migrations/*_create_articles.exs")

        assert_file(migration_file, fn content ->
          assert content =~ "add :title, :string"
          assert content =~ "add :views, :integer"
          assert content =~ "add :rating, :float"
          assert content =~ "add :published, :boolean"
          assert content =~ "add :published_at, :utc_datetime"
        end)
      end)
    end

    test "raises with missing arguments" do
      assert_raise Mix.Error, ~r/expected immutable.gen.migration to receive/, fn ->
        run([])
      end
    end
  end

  defp in_tmp(fun) do
    path = Path.join(@tmp_path, "my_app")
    File.mkdir_p!(path)

    File.cd!(path, fn ->
      File.mkdir_p!("lib/my_app")
      File.mkdir_p!("priv/repo/migrations")

      Mix.Project.in_project(:my_app, ".", fn _module ->
        fun.()
      end)
    end)
  end

  defp assert_file(path) do
    assert File.exists?(path), "Expected #{path} to exist, but it does not"
  end

  defp assert_file(path, fun) do
    assert_file(path)
    fun.(File.read!(path))
  end
end
