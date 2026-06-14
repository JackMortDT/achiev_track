defmodule AchievTrackWeb.SyncJSON do
  def status(%{status: s}) do
    %{
      allowed: s.allowed,
      syncs_used: s.syncs_used,
      syncs_remaining: s.syncs_remaining,
      next_available_at: format_dt(s.next_available_at)
    }
  end

  def triggered(%{status: s}) do
    %{
      ok: true,
      syncs_remaining: s.syncs_remaining,
      next_available_at: format_dt(s.next_available_at)
    }
  end

  def rate_limited(%{status: s}) do
    %{
      error: "rate_limited",
      syncs_remaining: 0,
      next_available_at: format_dt(s.next_available_at)
    }
  end

  defp format_dt(nil), do: nil
  defp format_dt(%DateTime{} = dt), do: DateTime.to_iso8601(dt)
end
