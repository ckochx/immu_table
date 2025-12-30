defmodule Mix.Tasks.Immutable.Gen.SchemaTest do
  use ExUnit.Case, async: false

  import Mix.Tasks.Immutable.Gen.Schema, only: [run: 1]

  @tmp_path Path.expand("../../tmp", __DIR__)

  setup do
    File.rm_rf!(@tmp_path)
    File.mkdir_p!(@tmp_path)
    on_exit(fn -> File.rm_rf!(@tmp_path) end)
    :ok
  end

  describe "run/1" do
    test "generates a schema file with immutable_schema" do
      in_tmp(fn ->
        run(["Blog.Post", "posts", "title:string", "body:text"])

        assert_file("lib/my_app/blog/post.ex", fn content ->
          assert content =~ "defmodule MyApp.Blog.Post do"
          assert content =~ "use Ecto.Schema"
          assert content =~ "use ImmuTable"
          assert content =~ "import Ecto.Changeset, except: [cast: 3]"
          assert content =~ "immutable_schema \"posts\" do"
          assert content =~ "field :title, :string"
          assert content =~ "field :body, :string"
          assert content =~ "def changeset("
          assert content =~ "|> cast(attrs, [:title, :body])"
        end)
      end)
    end

    test "generates schema with validation for required fields" do
      in_tmp(fn ->
        run(["Blog.Post", "posts", "title:string", "body:text"])

        assert_file("lib/my_app/blog/post.ex", fn content ->
          assert content =~ "validate_required([:title, :body])"
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

        assert_file("lib/my_app/blog/article.ex", fn content ->
          assert content =~ "field :title, :string"
          assert content =~ "field :views, :integer"
          assert content =~ "field :rating, :float"
          assert content =~ "field :published, :boolean"
          assert content =~ "field :published_at, :utc_datetime"
        end)
      end)
    end

    test "generates schema with references as uuid type" do
      in_tmp(fn ->
        run(["Blog.Comment", "comments", "body:text", "post_id:references:posts"])

        assert_file("lib/my_app/blog/comment.ex", fn content ->
          assert content =~ "field :post_id, Ecto.UUID"
        end)
      end)
    end

    test "raises with missing arguments" do
      assert_raise Mix.Error, ~r/expected immutable.gen.schema to receive/, fn ->
        run([])
      end

      assert_raise Mix.Error, ~r/expected immutable.gen.schema to receive/, fn ->
        run(["Blog.Post"])
      end
    end

    test "raises with invalid module name" do
      assert_raise Mix.Error, ~r/expected the schema.*to be a valid module name/, fn ->
        run(["blog.post", "posts", "title:string"])
      end
    end

    test "raises with invalid table name" do
      assert_raise Mix.Error, ~r/expected the table name/, fn ->
        run(["Blog.Post", "Posts", "title:string"])
      end
    end
  end

  defp in_tmp(fun) do
    path = Path.join(@tmp_path, "my_app")
    File.mkdir_p!(path)

    File.cd!(path, fn ->
      File.mkdir_p!("lib/my_app")

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
