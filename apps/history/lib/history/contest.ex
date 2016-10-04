defmodule History.Contest do
  use Ecto.Schema
  import Ecto.Changeset
  require Ecto.Query

  schema "contests" do
    field :name, :string
    field :start, Ecto.DateTime
    field :finish, Ecto.DateTime
    has_many :challenges, History.Challenge
  end

  @required_fields ~w()
  @optional_fields ~w(name start finish)

  def changeset(record, params \\ %{}) do
    cast(record, params, @required_fields ++ @optional_fields)
    |> cast_assoc(:challenges)
  end

  def at_timestamp(timestamp) do
    Ecto.Query.from(c in History.Contest,
                    where: (c.start <= ^timestamp and
                            c.finish > ^timestamp),
                    limit: 1)
    |> History.Repo.one
  end

  def find_challenge(contest, challenge_name) do
    History.Repo.preload(contest, :challenges).challenges
    |> Enum.filter(fn challenge -> challenge.name == challenge_name end)
    |> List.first
  end
end
