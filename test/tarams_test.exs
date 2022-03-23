defmodule ParamTest.StringList do
  def cast(value) when is_binary(value) do
    rs =
      String.split(value, ",")
      |> Tarams.scrub_param()
      |> Tarams.clean_nil()

    {:ok, rs}
  end

  def cast(_), do: :error
end

defmodule ParamTest do
  use ExUnit.Case
  alias Tarams

  defmodule Address do
    defstruct [:province, :city]
  end

  describe "test srub_params" do
    test "scrub empty string to nil" do
      params = %{"email" => "", "type" => "customer"}
      assert %{"email" => nil, "type" => "customer"} = Tarams.scrub_param(params)
    end

    test "scrub string with all space to nil" do
      params = %{"email" => "   ", "type" => "customer"}
      assert %{"email" => nil, "type" => "customer"} = Tarams.scrub_param(params)
    end

    test "scrub success with atom key" do
      params = %{email: "   ", password: "123"}
      assert %{email: nil, password: "123"} = Tarams.scrub_param(params)
    end

    test "scrub success with nested map" do
      params = %{
        email: "   ",
        password: "123",
        address: %{street: "", province: "   ", city: "HCM"}
      }

      assert %{address: %{street: nil, province: nil, city: "HCM"}} = Tarams.scrub_param(params)
    end

    test "scrub array params" do
      params = %{ids: [1, 2, "3", "", "  "]}
      assert %{ids: [1, 2, "3", nil, nil]} = Tarams.scrub_param(params)
    end

    test "scrub success with mix atom and string key" do
      params = %{email: "   "} |> Map.put("type", "customer")
      assert %{email: nil} = Tarams.scrub_param(params)
    end

    test "scrub skip struct" do
      params = %{
        "email" => "   ",
        "type" => "customer",
        "address" => %Address{province: "   ", city: "Hochiminh"}
      }

      assert %{"address" => %Address{province: "   ", city: "Hochiminh"}} =
               Tarams.scrub_param(params)
    end

    test "scrub plug" do
      params = %{email: "   ", password: "123"}
      assert %{params: %{email: nil, password: "123"}} = Tarams.plug_scrub(%{params: params})
      assert %{params: %{email: nil}} = Tarams.plug_scrub(%{params: params}, [:email, :name])
    end
  end

  describe "test clean_nil" do
    test "clean nil map" do
      params = %{"email" => nil, "type" => "customer"}
      assert %{"type" => "customer"} = Tarams.clean_nil(params)
    end

    test "scrub nil success with list" do
      params = %{ids: [2, nil, 3, nil]}
      assert %{ids: [2, 3]} = Tarams.clean_nil(params)
    end

    test "clean nil success with nested map" do
      params = %{
        email: nil,
        password: "123",
        address: %{street: nil, province: nil, city: "HCM"}
      }

      assert %{address: %{city: "HCM"}} = Tarams.clean_nil(params)
    end

    test "clean nil success with nested  list" do
      params = %{
        users: [
          %{
            name: nil,
            age: 20,
            hobbies: ["cooking", nil]
          },
          nil
        ]
      }

      assert %{
               users: [
                 %{
                   age: 20,
                   hobbies: ["cooking"]
                 }
               ]
             } == Tarams.clean_nil(params)
    end

    test "clean nil skip struct" do
      params = %{
        "email" => "dn@gmail.com",
        "type" => "customer",
        "address" => %Address{province: nil, city: "Hochiminh"}
      }

      assert %{"address" => %Address{province: nil, city: "Hochiminh"}} = Tarams.clean_nil(params)
    end
  end

  alias ParamTest.StringList

  describe "Tarams.cast" do
    @type_checks [
      [:string, "Bluz", "Bluz", :ok],
      [:string, 10, nil, :error],
      [:binary, "Bluz", "Bluz", :ok],
      [:binary, true, nil, :error],
      [:boolean, "1", true, :ok],
      [:boolean, "true", true, :ok],
      [:boolean, "0", false, :ok],
      [:boolean, "false", false, :ok],
      [:boolean, true, true, :ok],
      [:boolean, 10, nil, :error],
      [:integer, 10, 10, :ok],
      [:integer, "10", 10, :ok],
      [:integer, 10.0, nil, :error],
      [:integer, "10.0", nil, :error],
      [:float, 10.1, 10.1, :ok],
      [:float, "10.1", 10.1, :ok],
      [:float, 10, 10.0, :ok],
      [:float, "10", 10.0, :ok],
      [:float, "10xx", nil, :error],
      [:map, %{name: "Bluz"}, %{name: "Bluz"}, :ok],
      [:map, %{"name" => "Bluz"}, %{"name" => "Bluz"}, :ok],
      [:map, [], nil, :error],
      [{:array, :integer}, [1, 2, 3], [1, 2, 3], :ok],
      [{:array, :integer}, ["1", "2", "3"], [1, 2, 3], :ok],
      [{:array, :string}, ["1", "2", "3"], ["1", "2", "3"], :ok],
      [StringList, "1,2,3", ["1", "2", "3"], :ok],
      [StringList, "", [], :ok],
      [StringList, [], nil, :error],
      [{:array, StringList}, ["1", "2"], [["1"], ["2"]], :ok],
      [{:array, StringList}, [1, 2], nil, :error],
      [:date, "2020-10-11", ~D[2020-10-11], :ok],
      [:date, "2020-10-11T01:01:01", ~D[2020-10-11], :ok],
      [:date, ~D[2020-10-11], ~D[2020-10-11], :ok],
      [:date, ~N[2020-10-11 01:00:00], ~D[2020-10-11], :ok],
      [:date, ~U[2020-10-11 01:00:00Z], ~D[2020-10-11], :ok],
      [:date, "2", nil, :error],
      [:time, "01:01:01", ~T[01:01:01], :ok],
      [:time, ~N[2020-10-11 01:01:01], ~T[01:01:01], :ok],
      [:time, ~U[2020-10-11 01:01:01Z], ~T[01:01:01], :ok],
      [:time, ~T[01:01:01], ~T[01:01:01], :ok],
      [:time, "2", nil, :error],
      [:naive_datetime, "-2020-10-11 01:01:01", ~N[-2020-10-11 01:01:01], :ok],
      [:naive_datetime, "2020-10-11 01:01:01", ~N[2020-10-11 01:01:01], :ok],
      [:naive_datetime, "2020-10-11 01:01:01+07", ~N[2020-10-11 01:01:01], :ok],
      [:naive_datetime, ~N[2020-10-11 01:01:01], ~N[2020-10-11 01:01:01], :ok],
      [
        :naive_datetime,
        %{year: 2020, month: 10, day: 11, hour: 1, minute: 1, second: 1},
        ~N[2020-10-11 01:01:01],
        :ok
      ],
      [
        :naive_datetime,
        %{year: "", month: 10, day: 11, hour: 1, minute: 1, second: 1},
        nil,
        :error
      ],
      [
        :naive_datetime,
        %{year: "", month: "", day: "", hour: "", minute: "", second: ""},
        nil,
        :ok
      ],
      [:naive_datetime, "2", nil, :error],
      [:naive_datetime, true, nil, :error],
      [:datetime, "-2020-10-11 01:01:01", ~U[-2020-10-11 01:01:01Z], :ok],
      [:datetime, "2020-10-11 01:01:01", ~U[2020-10-11 01:01:01Z], :ok],
      [:datetime, "2020-10-11 01:01:01-07", ~U[2020-10-11 08:01:01Z], :ok],
      [:datetime, ~N[2020-10-11 01:01:01], ~U[2020-10-11 01:01:01Z], :ok],
      [:datetime, ~U[2020-10-11 01:01:01Z], ~U[2020-10-11 01:01:01Z], :ok],
      [:datetime, "2", nil, :error],
      [:utc_datetime, "-2020-10-11 01:01:01", ~U[-2020-10-11 01:01:01Z], :ok],
      [:utc_datetime, "2020-10-11 01:01:01", ~U[2020-10-11 01:01:01Z], :ok],
      [:utc_datetime, "2020-10-11 01:01:01-07", ~U[2020-10-11 08:01:01Z], :ok],
      [:utc_datetime, ~N[2020-10-11 01:01:01], ~U[2020-10-11 01:01:01Z], :ok],
      [:utc_datetime, ~U[2020-10-11 01:01:01Z], ~U[2020-10-11 01:01:01Z], :ok],
      [:utc_datetime, "2", nil, :error],
      [:any, "any", "any", :ok]
    ]

    test "cast base type" do
      @type_checks
      |> Enum.each(fn [type, value, expected_value, expect] ->
        rs =
          Tarams.cast(%{"key" => value}, %{
            key: type
          })

        if expect == :ok do
          assert {:ok, %{key: ^expected_value}} = rs
        else
          assert {:error, _} = rs
        end
      end)
    end

    test "schema short hand" do
      assert {:ok, %{number: 10}} = Tarams.cast(%{number: "10"}, %{number: :integer})

      assert {:ok, %{number: 10}} =
               Tarams.cast(%{number: "10"}, %{number: [:integer, number: [min: 5]]})
    end

    test "cast ok" do
      assert 10 = Tarams.Type.cast!(:integer, 10)
      assert 10 = Tarams.Type.cast!(:integer, "10")
    end

    test "cast raise exception" do
      assert_raise RuntimeError, fn ->
        Tarams.Type.cast!(:integer, "10xx")
      end
    end

    test "cast with alias" do
      schema = %{
        email: [type: :string, as: :user_email]
      }

      rs = Tarams.cast(%{email: "xx@yy.com"}, schema)
      assert {:ok, %{user_email: "xx@yy.com"}} = rs
    end

    test "cast use default value if field not exist in params" do
      assert {:ok, %{name: "Dzung"}} =
               Tarams.cast(%{}, %{name: [type: :string, default: "Dzung"]})
    end

    test "cast use default function if field not exist in params" do
      assert {:ok, %{name: "123"}} =
               Tarams.cast(%{}, %{name: [type: :string, default: fn -> "123" end]})
    end

    test "cast validate required skip if default is set" do
      assert {:ok, %{name: "Dzung"}} =
               Tarams.cast(%{}, %{name: [type: :string, default: "Dzung", required: true]})
    end

    test "cast func is used if set" do
      assert {:ok, %{name: "Dzung is so handsome"}} =
               Tarams.cast(%{name: "Dzung"}, %{
                 name: [
                   type: :string,
                   cast_func: fn value -> {:ok, "#{value} is so handsome"} end
                 ]
               })
    end

    @schema %{
      user: [
        type: %{
          name: [type: :string, required: true],
          email: [type: :string, length: [min: 5]],
          age: [type: :integer]
        }
      ]
    }

    test "cast embed type with valid value" do
      data = %{
        user: %{
          name: "D",
          email: "d@h.com",
          age: 10
        }
      }

      assert {:ok, ^data} = Tarams.cast(data, @schema)
    end

    test "cast with no value should default to nil and skip validation" do
      data = %{
        user: %{
          name: "D",
          age: 10
        }
      }

      assert {:ok, %{user: %{email: nil}}} = Tarams.cast(data, @schema)
    end

    test "cast embed validation invalid should error" do
      data = %{
        user: %{
          name: "D",
          email: "h",
          age: 10
        }
      }

      assert {:error, %{user: %{email: ["length must be greater than or equal to 5"]}}} =
               Tarams.cast(data, @schema)
    end

    test "cast missing required value should error" do
      data = %{
        user: %{
          age: 10
        }
      }

      assert {:error, %{user: %{name: ["is required"]}}} = Tarams.cast(data, @schema)
    end

    @array_schema %{
      user: [
        type:
          {:array,
           %{
             name: [type: :string, required: true],
             email: [type: :string],
             age: [type: :integer]
           }}
      ]
    }
    test "cast array embed schema with valid data" do
      data = %{
        "user" => [
          %{
            "name" => "D",
            "email" => "d@h.com",
            "age" => 10
          }
        ]
      }

      assert {:ok, %{user: [%{age: 10, email: "d@h.com", name: "D"}]}} =
               Tarams.cast(data, @array_schema)
    end

    test "cast empty array embed should ok" do
      data = %{
        "user" => []
      }

      assert {:ok, %{user: []}} = Tarams.cast(data, @array_schema)
    end

    test "cast nil array embed should ok" do
      data = %{
        "user" => nil
      }

      assert {:ok, %{user: nil}} = Tarams.cast(data, @array_schema)
    end

    test "cast array embed with invalid value should error" do
      data = %{
        "user" => [
          %{
            "email" => "d@h.com",
            "age" => 10
          },
          %{
            "name" => "HUH",
            "email" => "om",
            "age" => 10
          }
        ]
      }

      assert {:error, %{user: %{name: ["is required"]}}} = Tarams.cast(data, @array_schema)
    end

    test "error with custom message" do
      schema = %{
        age: [type: :integer, number: [min: 10], message: "so khong hop le"]
      }

      assert {:error, %{age: ["so khong hop le"]}} = Tarams.cast(%{"age" => "abc"}, schema)
      assert {:error, %{age: ["so khong hop le"]}} = Tarams.cast(%{"age" => "1"}, schema)
    end
  end
end
