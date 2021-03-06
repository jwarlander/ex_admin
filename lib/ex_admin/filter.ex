Code.ensure_compiled(ExAdmin.Utils)
defmodule ExAdmin.Filter do
  @moduledoc false
  require Logger
  require Ecto.Query
  import ExAdmin.Theme.Helpers
  # import ExAdmin.Utils
  use Xain

  @integer_options [eq: "Equal To", gt: "Greater Than", lt: "Less Than" ]

  def integer_options, do: @integer_options

  def filter_view(_conn, nil, _defn), do: ""
  def filter_view(_conn, false, _defn), do: ""
  def filter_view(conn, _filters, defn) do
    q = conn.params["q"]
    order = conn.params["order"]
    scope = conn.params["scope"]
    theme_module(conn, Filter).theme_filter_view(conn, defn, q, order, scope)
  end

  def fields(%{index_filters: []} = defn) do
    for field <- defn.resource_model.__schema__(:fields) -- [:id] do
      {field, defn.resource_model.__schema__(:type, field)}
    end
  end

  def fields(%{index_filters: [[{:except, except_filters}]]} = defn) do
    for field <- defn.resource_model.__schema__(:fields) -- [:id | except_filters] do
      {field, defn.resource_model.__schema__(:type, field)}
    end
  end

  def fields(%{index_filters: [[{:only, filters}]]} = defn),
    do: fields(Map.put(defn, :index_filters, [filters]))

  def fields(%{index_filters: [filters]} = defn) do
    for field <- filters do
      {field, defn.resource_model.__schema__(:type, field)}
    end
  end

  def associations(defn) do
    Enum.reduce defn.resource_model.__schema__(:associations), [], fn(assoc, acc) ->
      case defn.resource_model.__schema__(:association, assoc) do
        %Ecto.Association.BelongsTo{} = belongs_to -> [{assoc, belongs_to} | acc]
        _ -> acc
      end
    end
  end

  def check_and_build_association(name, q, defn) do
    name_str = Atom.to_string name
    if String.match? name_str, ~r/_id$/ do
      Enum.map(defn.resource_model.__schema__(:associations), &(defn.resource_model.__schema__(:association, &1)))
      |> Enum.find(fn(assoc) ->
        case assoc do
          %Ecto.Association.BelongsTo{owner_key: ^name} ->
            theme_module(Filter).build_field {name, assoc}, q, defn
            true
          _ ->
            false
        end
      end)
    else
      false
    end
  end

  def integer_selected_name(name, nil), do: "#{name}_eq"
  def integer_selected_name(name, q) do
    Enum.reduce(integer_options, "#{name}_eq", fn({k,_}, acc) ->
      if q["#{name}_#{k}"], do: "#{name}_#{k}", else: acc
    end)
  end

  def get_value(_, nil), do: ""
  def get_value(name, q), do: Map.get(q, name, "")

  def get_integer_value(_, nil), do: ""
  def get_integer_value(name, q) do
    Map.to_list(q)
    |> Enum.find(fn({k,_v}) -> String.starts_with?(k, "#{name}") end)
    |> case do
      {_k, v} -> v
      _ -> ""
    end
  end

  def build_option(text, name, selected_name) do
    selected = if name == selected_name, do: [selected: "selected"], else: []
    option text, [value: name] ++ selected
  end
end
