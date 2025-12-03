defmodule ImmuTable.AssociationsTest do
  use ImmuTable.DataCase, async: true

  defmodule Organization do
    use Ecto.Schema
    use ImmuTable

    immutable_schema "organizations" do
      field(:name, :string)
    end
  end

  defmodule Project do
    use Ecto.Schema
    use ImmuTable

    import ImmuTable.Associations

    immutable_schema "projects" do
      field(:title, :string)
      field(:description, :string)

      immutable_belongs_to(:organization, Organization)
    end
  end

  describe "immutable_belongs_to/3 macro" do
    test "creates {field}_entity_id field" do
      project = %Project{}
      assert Map.has_key?(project, :organization_entity_id)
    end

    test "does not create standard {field}_id field" do
      project = %Project{}
      refute Map.has_key?(project, :organization_id)
    end

    test "field has correct type (Ecto.UUID)" do
      assert Project.__schema__(:type, :organization_entity_id) == Ecto.UUID
    end
  end

  describe "storing and retrieving associations" do
    test "stores entity_id of associated record" do
      {:ok, org} = ImmuTable.insert(TestRepo, %Organization{name: "Acme Corp"})

      {:ok, project} =
        ImmuTable.insert(TestRepo, %Project{
          title: "Project Alpha",
          organization_entity_id: org.entity_id
        })

      assert project.organization_entity_id == org.entity_id
    end

    test "can retrieve associated record by entity_id" do
      {:ok, org} = ImmuTable.insert(TestRepo, %Organization{name: "Acme Corp"})

      {:ok, project} =
        ImmuTable.insert(TestRepo, %Project{
          title: "Project Alpha",
          organization_entity_id: org.entity_id
        })

      loaded_project = TestRepo.get(Project, project.id)
      assert loaded_project.organization_entity_id == org.entity_id
    end
  end

  describe "ImmuTable.preload/3 - preloading current versions" do
    test "preloads current version of associated entity" do
      {:ok, org} = ImmuTable.insert(TestRepo, %Organization{name: "Acme Corp"})

      {:ok, project} =
        ImmuTable.insert(TestRepo, %Project{
          title: "Project Alpha",
          organization_entity_id: org.entity_id
        })

      loaded_project =
        project
        |> TestRepo.reload()
        |> ImmuTable.preload(TestRepo, :organization)

      assert loaded_project.organization.entity_id == org.entity_id
      assert loaded_project.organization.name == "Acme Corp"
      assert loaded_project.organization.deleted_at == nil
    end

    test "preloads current version after associated entity updated" do
      {:ok, org_v1} = ImmuTable.insert(TestRepo, %Organization{name: "Acme Corp"})

      {:ok, project} =
        ImmuTable.insert(TestRepo, %Project{
          title: "Project Alpha",
          organization_entity_id: org_v1.entity_id
        })

      {:ok, org_v2} = ImmuTable.update(TestRepo, org_v1, %{name: "Acme Corporation"})

      loaded_project =
        project
        |> TestRepo.reload()
        |> ImmuTable.preload(TestRepo, :organization)

      assert loaded_project.organization.id == org_v2.id
      assert loaded_project.organization.name == "Acme Corporation"
      assert loaded_project.organization.version == 2
    end

    test "preloads multiple associations" do
      {:ok, org} = ImmuTable.insert(TestRepo, %Organization{name: "Acme Corp"})

      {:ok, project1} =
        ImmuTable.insert(TestRepo, %Project{
          title: "Project Alpha",
          organization_entity_id: org.entity_id
        })

      {:ok, project2} =
        ImmuTable.insert(TestRepo, %Project{
          title: "Project Beta",
          organization_entity_id: org.entity_id
        })

      projects =
        [project1, project2]
        |> ImmuTable.preload(TestRepo, :organization)

      assert Enum.all?(projects, fn p -> p.organization.name == "Acme Corp" end)
    end

    test "returns nil when associated entity is deleted" do
      {:ok, org} = ImmuTable.insert(TestRepo, %Organization{name: "Acme Corp"})

      {:ok, project} =
        ImmuTable.insert(TestRepo, %Project{
          title: "Project Alpha",
          organization_entity_id: org.entity_id
        })

      {:ok, _deleted} = ImmuTable.delete(TestRepo, org)

      loaded_project =
        project
        |> TestRepo.reload()
        |> ImmuTable.preload(TestRepo, :organization)

      assert loaded_project.organization == nil
    end

    test "preloads after associated entity delete/undelete cycle" do
      {:ok, org_v1} = ImmuTable.insert(TestRepo, %Organization{name: "Acme Corp"})

      {:ok, project} =
        ImmuTable.insert(TestRepo, %Project{
          title: "Project Alpha",
          organization_entity_id: org_v1.entity_id
        })

      {:ok, deleted} = ImmuTable.delete(TestRepo, org_v1)
      {:ok, org_v3} = ImmuTable.undelete(TestRepo, deleted)

      loaded_project =
        project
        |> TestRepo.reload()
        |> ImmuTable.preload(TestRepo, :organization)

      assert loaded_project.organization.id == org_v3.id
      assert loaded_project.organization.name == "Acme Corp"
      assert loaded_project.organization.deleted_at == nil
      assert loaded_project.organization.version == 3
    end
  end

  describe "ImmuTable.assoc/2 - building queries with associations" do
    test "builds query to find all projects for an organization" do
      {:ok, org1} = ImmuTable.insert(TestRepo, %Organization{name: "Acme Corp"})
      {:ok, org2} = ImmuTable.insert(TestRepo, %Organization{name: "Other Corp"})

      {:ok, _p1} =
        ImmuTable.insert(TestRepo, %Project{
          title: "Project Alpha",
          organization_entity_id: org1.entity_id
        })

      {:ok, _p2} =
        ImmuTable.insert(TestRepo, %Project{
          title: "Project Beta",
          organization_entity_id: org1.entity_id
        })

      {:ok, _p3} =
        ImmuTable.insert(TestRepo, %Project{
          title: "Project Gamma",
          organization_entity_id: org2.entity_id
        })

      import Ecto.Query

      projects =
        Project
        |> ImmuTable.Query.current()
        |> where([p], p.organization_entity_id == ^org1.entity_id)
        |> TestRepo.all()

      assert length(projects) == 2
      assert Enum.all?(projects, fn p -> p.organization_entity_id == org1.entity_id end)
    end

    test "joins with current version of associated entity" do
      {:ok, org} = ImmuTable.insert(TestRepo, %Organization{name: "Acme Corp"})

      {:ok, _project} =
        ImmuTable.insert(TestRepo, %Project{
          title: "Project Alpha",
          organization_entity_id: org.entity_id
        })

      import Ecto.Query

      results =
        Project
        |> ImmuTable.Query.current()
        |> ImmuTable.join(:organization)
        |> select([p, _p_current, org], {p.title, org.name})
        |> TestRepo.all()

      assert results == [{"Project Alpha", "Acme Corp"}]
    end

    test "join excludes deleted associations" do
      {:ok, org} = ImmuTable.insert(TestRepo, %Organization{name: "Acme Corp"})

      {:ok, _project} =
        ImmuTable.insert(TestRepo, %Project{
          title: "Project Alpha",
          organization_entity_id: org.entity_id
        })

      {:ok, _deleted} = ImmuTable.delete(TestRepo, org)

      import Ecto.Query

      results =
        Project
        |> ImmuTable.Query.current()
        |> ImmuTable.join(:organization)
        |> select([p, _p_current, org], {p.title, org.name})
        |> TestRepo.all()

      assert results == []
    end
  end
end
