defmodule Tarams.Schema do
  defstruct types: %{},
            default: %{},
            validators: %{},
            required_fields: [],
            custom_cast_funcs: [],
            embedded_fields: []
end

defmodule Tarams.SchemaParser do
  def parse(schema) do
    schema = standardize(schema)

    %{
      types: get_types(schema),
      default: get_default(schema),
      validators: get_validators(schema),
      required_fields: get_required_fields(schema),
      custom_cast_funcs: get_custom_cast_funcs(schema),
      embedded_fields: get_embedded_fields(schema)
    }
  end

  defp standardize(schema) do
    Enum.map(schema, fn {field_name, field_def} ->
      cond do
        is_atom(field_def) or is_map(field_def) or is_tuple(field_def) ->
          # map is nested schema
          {field_name, [type: field_def]}

        is_list(field_def) ->
          {field_name, field_def}

        true ->
          raise "invalid field declaration"
      end
    end)
  end

  # Extract field type, support all ecto type
  defp get_types(schema) do
    types =
      Enum.map(schema, fn
        {field, opts} when is_list(opts) ->
          if Keyword.has_key?(opts, :type) do
            {field, construct_type(field, opts[:type])}
          else
            raise "Type is missing"
          end
      end)

    Enum.into(types, %{})
  end

  defp construct_type(field, {:array, %{} = _schema}) do
    {:embed,
     %Ecto.Embedded{
       cardinality: :many,
       field: field,
       owner: nil,
       related: nil,
       unique: true
     }}
  end

  defp construct_type(field, %{} = _schema) do
    {:embed,
     %Ecto.Embedded{
       cardinality: :one,
       field: field,
       owner: nil,
       related: nil,
       unique: true
     }}
  end

  defp construct_type(_field, type), do: type

  # Extract field default value, if default value is function, it is invoked
  defp get_default(schema) do
    default =
      Enum.map(schema, fn {field, opts} ->
        default = Keyword.get(opts, :default)

        default =
          if is_function(default) do
            default.()
          else
            default
          end

        {field, default}
      end)

    Enum.into(default, %{})
  end

  # Extract field and validator for each field
  defp get_validators(schema) do
    Enum.map(schema, fn {field, opts} ->
      {field, Keyword.get(opts, :validate)}
    end)
    |> Enum.filter(&(not is_nil(elem(&1, 1))))
  end

  # List required fields, field with option `required: true`, from schema
  defp get_required_fields(schema) do
    Enum.filter(schema, fn {_, opts} ->
      Keyword.get(opts, :required) == true
    end)
    |> Enum.map(&elem(&1, 0))
  end

  # list field with custom cast function
  defp get_custom_cast_funcs(schema) do
    Enum.filter(schema, fn {_, opts} ->
      cast_func = Keyword.get(opts, :cast_func)

      cond do
        is_nil(cast_func) -> false
        is_function(cast_func) -> true
        true -> raise RuntimeError, ":cast_func must be a function"
      end
    end)
    |> Enum.into(%{})
  end

  defp get_embedded_fields(schema) do
    Enum.filter(schema, fn {_, opts} ->
      is_embedded_type(opts[:type])
    end)
    |> Enum.into(%{})
  end

  # embeded type is {:array , %{<schema>}} or %{<schema>}
  defp is_embedded_type({:array, %{}}), do: true

  defp is_embedded_type(%{}), do: true

  defp is_embedded_type(_), do: false
end
