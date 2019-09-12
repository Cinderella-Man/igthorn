defmodule Hefty.Repo.Migrations.CreateSettingsTable do
  use Ecto.Migration

  def change do
    create table(:settings, primary_key: false) do
      add(:id, :bigint, primary_key: true)
      add(:key, :text, null: false)
      add(:value, :text, null: true)

      timestamps()
    end
  end
end
