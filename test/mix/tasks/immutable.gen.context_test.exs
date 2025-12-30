defmodule Mix.Tasks.Immutable.Gen.ContextTest do
  use ExUnit.Case, async: false

  import Mix.Tasks.Immutable.Gen.Context, only: [run: 1]

  @tmp_path Path.expand("../../tmp", __DIR__)

  setup do
    File.rm_rf!(@tmp_path)
    File.mkdir_p!(@tmp_path)
    on_exit(fn -> File.rm_rf!(@tmp_path) end)
    :ok
  end

  describe "run/1" do
    test "generates a context module with ImmuTable operations" do
      in_tmp(fn ->
        run(["Blog", "Post", "posts", "title:string", "body:text"])

        assert_file("lib/my_app/blog.ex", fn content ->
          assert content =~ "defmodule MyApp.Blog do"
          assert content =~ "alias MyApp.Repo"
          assert content =~ "alias MyApp.Blog.Post"
          assert content =~ "def list_posts do"
          assert content =~ "ImmuTable.Query.get_current()"
          assert content =~ "def get_post!(entity_id) do"
          assert content =~ "ImmuTable.get!(Post, Repo, entity_id)"
          assert content =~ "def get_post(entity_id) do"
          assert content =~ "ImmuTable.get(Post, Repo, entity_id)"
          assert content =~ "def create_post(attrs) do"
          assert content =~ "ImmuTable.insert(Repo, changeset)"
          assert content =~ "def update_post(%Post{} = post, attrs) do"
          assert content =~ "ImmuTable.update(Repo)"
          assert content =~ "def delete_post(%Post{} = post) do"
          assert content =~ "ImmuTable.delete(Repo, post)"
          assert content =~ "def get_post_history(entity_id) do"
          assert content =~ "ImmuTable.Query.history(entity_id)"
          assert content =~ "def undelete_post(%Post{} = post"
          assert content =~ "def change_post(%Post{} = post"
        end)
      end)
    end

    test "generates schema along with context" do
      in_tmp(fn ->
        run(["Blog", "Post", "posts", "title:string", "body:text"])

        assert_file("lib/my_app/blog/post.ex", fn content ->
          assert content =~ "defmodule MyApp.Blog.Post do"
          assert content =~ "immutable_schema \"posts\""
        end)
      end)
    end

    test "raises with missing arguments" do
      assert_raise Mix.Error, ~r/expected immutable.gen.context to receive/, fn ->
        run([])
      end

      assert_raise Mix.Error, ~r/expected immutable.gen.context to receive/, fn ->
        run(["Blog"])
      end

      assert_raise Mix.Error, ~r/expected immutable.gen.context to receive/, fn ->
        run(["Blog", "Post"])
      end
    end

    test "raises with invalid context name" do
      assert_raise Mix.Error, ~r/expected the context.*to be a valid module name/, fn ->
        run(["blog", "Post", "posts", "title:string"])
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
