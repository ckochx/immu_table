defmodule DemoWeb.Router do
  use DemoWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {DemoWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", DemoWeb do
    pipe_through :browser

    get "/", PageController, :home

    live "/tasks", TaskLive.Index, :index
    live "/tasks/deleted", TaskLive.Deleted, :deleted
    live "/tasks/new", TaskLive.Form, :new
    live "/tasks/:entity_id", TaskLive.Show, :show
    live "/tasks/:entity_id/edit", TaskLive.Form, :edit
    live "/tasks/:entity_id/history", TaskLive.History, :history
  end

  # Other scopes may use custom stacks.
  # scope "/api", DemoWeb do
  #   pipe_through :api
  # end
end
