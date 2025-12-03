defmodule ImmuTable.AssociationsTest do
  use ImmuTable.DataCase, async: true

  defmodule Project do
    use Ecto.Schema
    use ImmuTable

    immutable_schema "projects" do
      field(:title, :string)
      field(:description, :string)

      immutable_belongs_to(:organization, ImmuTable.AssociationsTest.Organization)
      immutable_has_one(:lead_developer, ImmuTable.AssociationsTest.Developer, foreign_key: :project_entity_id)
    end
  end

  defmodule Organization do
    use Ecto.Schema
    use ImmuTable

    immutable_schema "organizations" do
      field(:name, :string)

      immutable_has_many(:projects, ImmuTable.AssociationsTest.Project, foreign_key: :organization_entity_id)
    end
  end

  defmodule Developer do
    use Ecto.Schema
    use ImmuTable

    immutable_schema "developers" do
      field(:name, :string)
      field(:project_entity_id, Ecto.UUID)
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

  describe "immutable_has_many/3 - preloading" do
    test "preloads current versions of associated records" do
      {:ok, org} = ImmuTable.insert(TestRepo, %Organization{name: "Acme Corp"})

      {:ok, _p1} =
        ImmuTable.insert(TestRepo, %Project{
          title: "Project Alpha",
          organization_entity_id: org.entity_id
        })

      {:ok, _p2} =
        ImmuTable.insert(TestRepo, %Project{
          title: "Project Beta",
          organization_entity_id: org.entity_id
        })

      loaded_org =
        org
        |> TestRepo.reload()
        |> ImmuTable.preload(TestRepo, :projects)

      assert length(loaded_org.projects) == 2
      assert Enum.map(loaded_org.projects, & &1.title) |> Enum.sort() == ["Project Alpha", "Project Beta"]
    end

    test "preloads empty list when no associated records" do
      {:ok, org} = ImmuTable.insert(TestRepo, %Organization{name: "Acme Corp"})

      loaded_org =
        org
        |> TestRepo.reload()
        |> ImmuTable.preload(TestRepo, :projects)

      assert loaded_org.projects == []
    end

    test "preloads after associated records updated" do
      {:ok, org} = ImmuTable.insert(TestRepo, %Organization{name: "Acme Corp"})

      {:ok, p1} =
        ImmuTable.insert(TestRepo, %Project{
          title: "Project Alpha",
          organization_entity_id: org.entity_id
        })

      {:ok, _p1_v2} = ImmuTable.update(TestRepo, p1, %{title: "Project Alpha Updated"})

      loaded_org =
        org
        |> TestRepo.reload()
        |> ImmuTable.preload(TestRepo, :projects)

      assert length(loaded_org.projects) == 1
      assert hd(loaded_org.projects).title == "Project Alpha Updated"
      assert hd(loaded_org.projects).version == 2
    end

    test "excludes deleted associated records" do
      {:ok, org} = ImmuTable.insert(TestRepo, %Organization{name: "Acme Corp"})

      {:ok, p1} =
        ImmuTable.insert(TestRepo, %Project{
          title: "Project Alpha",
          organization_entity_id: org.entity_id
        })

      {:ok, _p2} =
        ImmuTable.insert(TestRepo, %Project{
          title: "Project Beta",
          organization_entity_id: org.entity_id
        })

      {:ok, _deleted} = ImmuTable.delete(TestRepo, p1)

      loaded_org =
        org
        |> TestRepo.reload()
        |> ImmuTable.preload(TestRepo, :projects)

      assert length(loaded_org.projects) == 1
      assert hd(loaded_org.projects).title == "Project Beta"
    end

    test "batch preloads for multiple parents" do
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

      loaded_orgs =
        [org1, org2]
        |> ImmuTable.preload(TestRepo, :projects)

      assert length(Enum.at(loaded_orgs, 0).projects) == 2
      assert length(Enum.at(loaded_orgs, 1).projects) == 1
    end
  end

  describe "immutable_has_one/3 - preloading" do
    test "preloads current version of associated record" do
      {:ok, project} =
        ImmuTable.insert(TestRepo, %Project{
          title: "Project Alpha",
          organization_entity_id: nil
        })

      {:ok, _dev} =
        ImmuTable.insert(TestRepo, %Developer{
          name: "Alice",
          project_entity_id: project.entity_id
        })

      loaded_project =
        project
        |> TestRepo.reload()
        |> ImmuTable.preload(TestRepo, :lead_developer)

      assert loaded_project.lead_developer.name == "Alice"
    end

    test "preloads nil when no associated record" do
      {:ok, project} =
        ImmuTable.insert(TestRepo, %Project{
          title: "Project Alpha",
          organization_entity_id: nil
        })

      loaded_project =
        project
        |> TestRepo.reload()
        |> ImmuTable.preload(TestRepo, :lead_developer)

      assert loaded_project.lead_developer == nil
    end

    test "preloads after associated record updated" do
      {:ok, project} =
        ImmuTable.insert(TestRepo, %Project{
          title: "Project Alpha",
          organization_entity_id: nil
        })

      {:ok, dev} =
        ImmuTable.insert(TestRepo, %Developer{
          name: "Alice",
          project_entity_id: project.entity_id
        })

      {:ok, _dev_v2} = ImmuTable.update(TestRepo, dev, %{name: "Alice Smith"})

      loaded_project =
        project
        |> TestRepo.reload()
        |> ImmuTable.preload(TestRepo, :lead_developer)

      assert loaded_project.lead_developer.name == "Alice Smith"
      assert loaded_project.lead_developer.version == 2
    end

    test "preloads nil when associated record deleted" do
      {:ok, project} =
        ImmuTable.insert(TestRepo, %Project{
          title: "Project Alpha",
          organization_entity_id: nil
        })

      {:ok, dev} =
        ImmuTable.insert(TestRepo, %Developer{
          name: "Alice",
          project_entity_id: project.entity_id
        })

      {:ok, _deleted} = ImmuTable.delete(TestRepo, dev)

      loaded_project =
        project
        |> TestRepo.reload()
        |> ImmuTable.preload(TestRepo, :lead_developer)

      assert loaded_project.lead_developer == nil
    end

    test "batch preloads for multiple parents" do
      {:ok, p1} =
        ImmuTable.insert(TestRepo, %Project{
          title: "Project Alpha",
          organization_entity_id: nil
        })

      {:ok, p2} =
        ImmuTable.insert(TestRepo, %Project{
          title: "Project Beta",
          organization_entity_id: nil
        })

      {:ok, _dev1} =
        ImmuTable.insert(TestRepo, %Developer{
          name: "Alice",
          project_entity_id: p1.entity_id
        })

      {:ok, _dev2} =
        ImmuTable.insert(TestRepo, %Developer{
          name: "Bob",
          project_entity_id: p2.entity_id
        })

      loaded_projects =
        [p1, p2]
        |> ImmuTable.preload(TestRepo, :lead_developer)

      assert Enum.at(loaded_projects, 0).lead_developer.name == "Alice"
      assert Enum.at(loaded_projects, 1).lead_developer.name == "Bob"
    end
  end
end
