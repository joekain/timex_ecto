defmodule Timex.Ecto.DateTimeWithTimezone do
  @moduledoc """
  This is a special type for storing datetime + timezone information as a composite type.

  To use this, you must first make sure you have the `datetimetz` type defined in your database:

  ```sql
  CREATE TYPE datetimetz AS (
      dt timestamptz,
      tz varchar
  );
  ```

  Then you can use that type when creating your table, i.e.:

  ```sql
  CREATE TABLE example (
    id integer,
    created_at datetimetz
  );
  ```

  That's it!
  """
  use Timex

  @behaviour Ecto.Type

  def type, do: :datetimetz

  @doc """
  We can let Ecto handle blank input
  """
  defdelegate blank?(value), to: Ecto.Type

  @doc """
  Handle casting to Timex.Ecto.DateTimeWithTimezone
  """
  def cast(input) when is_binary(input) do
    case DateFormat.parse(input, "{ISO}") do
      {:ok, datetime} -> {:ok, datetime}
      {:error, _}     -> :error
    end
  end
  def cast(%DateTime{timezone: nil} = datetime), do: {:ok, %{datetime | :timezone => %TimezoneInfo{}}}
  def cast(%DateTime{} = datetime), do: {:ok, datetime}
  def cast(_), do: :error

  @doc """
  Load from the native Ecto representation
  """
  def load({ {{year, month, day}, {hour, min, sec, usec}}, timezone}) do
    datetime = Date.from({{year, month, day}, {hour, min, sec}})
    datetime = %{datetime | :ms => Time.from(usec, :usecs) |> Time.to_msecs}
    tz       = Timezone.get(timezone, datetime)
    {:ok, %{datetime | :timezone => tz}}
  end
  def load(_), do: :error

  @doc """
  Convert to the native Ecto representation
  """
  def dump(%DateTime{timezone: nil} = datetime) do
    {date, {hour, min, second}} = DateConvert.to_erlang_datetime(datetime)
    micros = datetime.ms * 1_000
    {:ok, {{date, {hour, min, second, micros}}, "UTC"}}
  end
  def dump(%DateTime{timezone: %TimezoneInfo{full_name: name}} = datetime) do
    {date, {hour, min, second}} = DateConvert.to_erlang_datetime(datetime)
    micros = datetime.ms * 1_000
    {:ok, {{date, {hour, min, second, micros}}, name}}
  end
  def dump(_), do: :error
end
