defmodule MyLiege.Engine.Place.ProjectTest do
  use ExUnit.Case, async: true

  alias MyLiege.Engine.Place
  alias MyLiege.Engine.Place.Project
  alias MyLiege.EngineFixtures

  test "a project is done once its progress reaches its target" do
    site = EngineFixtures.new_site(3, :market, target: 2)

    refute Project.done?(site)
    refute Project.done?(%{site | progress: 1})
    assert Project.done?(%{site | progress: 2})
  end

  test "a site has its own blueprint: no colour, no good" do
    site = EngineFixtures.new_site(3, :farm)

    assert Place.type(site) == :site
    assert Place.neutral?(site)
    assert Place.good(site) == nil
    assert site.blueprint.engine == :project
  end
end
