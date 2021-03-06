defmodule ExAdmin.Utils do
  @moduledoc """
  A collection of utility functions.
  """
  require Logger
  import Ecto.DateTime.Utils, only: [zero_pad: 2]
  @endpoint Application.get_env(:ex_admin, :endpoint)

  @doc false
  def endpoint, do: @endpoint

  @doc false
  def to_atom(string) when is_binary(string), do: String.to_atom(string)
  def to_atom(atom) when is_atom(atom), do: atom

  @doc false
  def base_name(item) when is_atom(item) do
    Atom.to_string(item)
    |> base_name
  end
  def base_name(item) do
    item
    |> String.split(".")
    |> List.last
  end

  @doc """
  Convert a field name to its human readable form.

  Converts items like field names to a form suitable for display
  labels and menu items. By default, converts _ to space and
  capitalizes each word.

  The conversion can be customized by passing a from regex and to
  regex as the 2nd and 3rd arguments.

  ## Examples:

      iex> humanize :first_name
      "First Name"

      iex> humanize "last-name", ~r/[-]/
      "Last Name"

  """
  def humanize(item, from \\ ~r/[_ ]/, to \\ " ")
  def humanize(atom, from, to) when is_atom(atom) do
    Atom.to_string(atom)
    |> humanize(from, to)
  end
  def humanize(string, from, to) when is_binary(string) do
    String.split(string, from)
    |> Enum.map(&(String.capitalize(&1)))
    |> Enum.join(to)
  end

  @doc """
  Converts camel case items to human readable form.

  ## Examples

      iex> titleize "MyModel"
      "My Model"

  """
  def titleize(atom) when is_atom(atom), do: titleize(Atom.to_string(atom))
  def titleize(string) when is_binary(string) do
    string
    |> Inflex.underscore
    |> humanize
  end

  @doc """
  Add a an or a in front of a word.

  ## Examples

      iex> articlize("hat")
      "a hat"

      iex> articlize("apple")
      "an apple"
  """
  def articlize(string) when is_binary(string) do
    if String.at(string, 0) in ~w(A a E e I i O o U u) do
      "an "
    else
      "a "
    end <> string
  end

  def parameterize(atom) when is_atom(atom),
    do: Atom.to_string(atom) |> parameterize
  def parameterize(str) when is_binary(str),
    do: Inflex.parameterize(str, "_")
    # do: str

  @doc false
  def action_name(conn) do
    Phoenix.Controller.action_name(conn)
  end


  @doc false
  def controller_name(name) when is_atom(name), do: extract_controller_name(name)
  def controller_name(%Plug.Conn{} = conn) do
    Phoenix.Controller.controller_module(conn)
    |> extract_controller_name
  end

  @doc false
  def resource_model(%Plug.Conn{path_info: path_info}) do
    ExAdmin.get_registered_by_controller_route(path_info)
    |> Map.get(:resource_model)
    |> base_name
  end

  def extract_controller_name(name) do
    base_name(name)
    |> String.split("Controller")
    |> List.first
  end

  @doc false
  def get_route_path(resource_or_conn, method, id \\ nil)
  def get_route_path(%Plug.Conn{path_info: path_info}, action, id) do
    get_route_path(Enum.take(path_info, 2), action, id)
  end
  def get_route_path(%{} = resource, method, id) do
    Map.get(resource, :__struct__)
    |> get_route_path(method, id)
  end
  def get_route_path(resource_model, method, id) when is_atom(resource_model) do
    route_name = ExAdmin.get_controller_path(resource_model)
    # prefix = UcxCallout.Router.Helpers.admin_path(@endpoint, :index, [])
    prefix = "/admin"
    |> String.split("/", trim: true)
    |> Enum.filter(&(&1 != :resource))
    get_route_path(prefix ++ [route_name], method, id)
  end

  def get_route_path(prefix, :index, _), do: path_append(prefix)
  def get_route_path(prefix, :new, _), do: path_append(prefix, ~w(new))
  def get_route_path(prefix, :edit, id), do: path_append(prefix, ~w(#{id} edit))
  def get_route_path(prefix, :show, id), do: path_append(prefix, ~w(#{id}))
  def get_route_path(prefix, :update, id), do: path_append(prefix, ~w(#{id}))
  def get_route_path(prefix, :create, _), do: path_append(prefix)
  def get_route_path(prefix, :destroy, id), do: path_append(prefix, ~w(#{id}))
  def get_route_path(prefix, :delete, id), do: path_append(prefix, ~w(#{id}))
  def get_route_path(prefix, :toggle, id), do: path_append(prefix, ~w(#{id} toggle))
  def get_route_path(prefix, :update_positions, opts), do: path_append(prefix, opts ++ ["update_positions"])

  defp path_append(prefix, rest \\ []) do
    "/" <> Enum.join(prefix ++ rest, "/")
  end


  @doc """
  Returns a list of items from list1 that are not in list2
  """
  def not_in(list1, list2) do
    Enum.reduce(list1, [], &(if &1 in list2, do: &2, else: [&1 | &2]))
    |> Enum.reverse
  end

  @doc """
  Generate html for a link

  ## Syntax
      iex> link_to("click me", "/something", class: "link btn", style: "some styling")
      {:safe, "<a href='/something' class='link btn' style='some styling'>click me</a>"}
  """
  def link_to(name, path, opts \\[]) do
    attributes = case Keyword.get(opts, :remote) do
      true ->
        Keyword.delete(opts, :remote)
        |> Keyword.put(:"data-remote", "true")
      _ -> opts
    end
    |> Enum.reduce("", fn({k,v}, acc) -> acc <> "#{k}='#{v}' " end)

    "<a href='#{path}' #{attributes}>#{name}</a>"
    |> Phoenix.HTML.raw
  end


  @doc false
  def confirm_message, do: "Are you sure you want to delete this?"

  @doc false
  def to_datetime(%Ecto.DateTime{} = dt) do
    {:ok, {date, {h,m,s,_ms}}} = Ecto.DateTime.dump dt
    {date, {h,m,s}}
  end

  @doc false
  def format_time_difference({d, {h, m, s}}) do
    h = d * 24 + h
    zero_pad(h,2) <> ":" <> zero_pad(m,2) <> ":" <> zero_pad(s, 2)
  end

  @doc false
  def format_datetime({{y,m,d}, {h,min,s}}) do
    zero_pad(y, 4) <> "-" <> zero_pad(m, 2) <> "-" <> zero_pad(d, 2) <> " " <>
    zero_pad(h, 2) <> ":" <> zero_pad(min, 2) <> ":" <> zero_pad(s, 2)
  end

  @doc """
  Return the plural of a term.

  Returns a string give an atom or a string.
  """
  def pluralize(atom) when is_atom(atom) do
    Atom.to_string(atom) |> pluralize
  end
  def pluralize(singular) when is_binary(singular) do
    Inflex.pluralize(singular)
  end

  @doc """
  Return the plural of a term based on a passed count.

  If count is equal to 1, return the singular. Otherwise, return the
  plural.

  """
  def pluralize(atom, count) when is_atom(atom),
    do: pluralize(Atom.to_string(atom), count)
  def pluralize(name, 1), do: Inflex.singularize(name)
  def pluralize(name, _), do: Inflex.pluralize(name)

  @doc false
  def get_resource_label(%Plug.Conn{} = conn) do
    menu = ExAdmin.get_registered_by_controller_route!(conn).menu
    Map.get menu, :label, resource_model(conn)
  end

  @doc false
  def displayable_name_plural(conn) do
    ExAdmin.Utils.get_resource_label(conn) |> Inflex.pluralize
  end
  def displayable_name_singular(conn) do
    ExAdmin.Utils.get_resource_label(conn) |> Inflex.singularize
  end

  @doc false
  def authorized_action?(conn, action, resource_model) when is_atom(resource_model) do
    fun = Application.get_env(:ex_admin, :authorize)
    if fun, do: fun.(conn, action, resource_model), else: true
  end
  def authorized_action?(conn, action, defn) do
    authorized_action?(conn, action, defn.resource_model)
  end

  @doc false
  def use_authentication do
    false
  end
end
