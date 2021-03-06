defmodule Arena.Match do
  def start(conn) do
    with(submission_time <- DateTime.utc_now(),
         {:ok, contest} <- History.Contest.at_timestamp(submission_time)) do
      main(conn, contest, submission_time)
    else
      _ -> write_line(conn, "No contest running.")
    end
    :gen_tcp.close(conn)
  end

  def main(conn, contest, submission_time) do
    with({:ok, team} <- ask_team(conn),
         {:ok, challenge} <- ask_challenge(conn, contest)) do
      attempt = History.Attempt.create(%{time: submission_time,
                                         team: team,
                                         challenge: challenge,
                                         status: "Running"})
      result = Arena.Test.run(conn, challenge, challenge.test_count)
      source = ask_source(conn, result)
      History.Attempt.update(attempt, %{status: result, source: source})
      write_line(conn, "#{result}.")
    else
      _ -> write_line(conn, "Invalid Submission.")
    end
  end

  def ask_team(conn) do
    with(write_line(conn, "Team:"),
         {:ok, team_name} <- read_line(conn, 200),
         write_line(conn, "Password:"),
         {:ok, team_password} <- read_line(conn, 200)) do
      History.Team.authenticate(team_name, team_password)
    else
      _ -> {:error}
    end
  end

  def ask_challenge(conn, contest) do
    with(write_line(conn, "Challenge:"),
         {:ok, challenge_name} <- read_line(conn, 200)) do
      History.Contest.find_challenge(contest, challenge_name)
    else
      _ -> {:error}
    end
  end

  def ask_source(conn, "Accepted") do
    write_line(conn, "Source:")
    IO.iodata_to_binary(Enum.reverse(read_source(conn, [], 1024)))
  end

  def ask_source(_conn, _result), do: nil

  defp read_line(conn, timeout) do
    case :gen_tcp.recv(conn, 0, timeout) do
      {:ok, message} -> {:ok, String.trim_trailing(message)}
      other -> other
    end
  end

  defp read_source(_conn, partial_source, 0) do
    partial_source
  end

  defp read_source(conn, partial_source, max_lines) do
    case read_line(conn, 200) do
      {:ok, line} -> read_source(conn, ["\n", line | partial_source], max_lines - 1)
      _error -> partial_source
    end
  end

  defp write_line(conn, line) do
    :gen_tcp.send(conn, line <> "\n")
  end
end
