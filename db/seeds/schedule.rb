# Schedule seed — runnable independently in production:
#   rails runner db/seeds/schedule.rb
#
# Idempotent: upserts ScheduleItem records by slug, then removes obsolete
# slugs from prior schedule versions. Safe to run repeatedly.

schedule_data = YAML.load_file(
  Rails.root.join("config/schedule.yml"),
  permitted_classes: [ Symbol ]
)

schedule_data[:days].each do |day|
  day[:items].each do |item|
    record = ScheduleItem.find_or_initialize_by(slug: item[:id])
    record.day         = day[:anchor]
    record.time_label  = item[:time]
    record.sort_time   = item[:sort_time]
    record.title       = item[:title]
    record.host        = item[:host]
    record.host_url    = item[:host_url]
    record.location    = item[:location]
    record.map_url     = item[:map_url]
    record.description = item[:description]
    record.kind        = item[:type]
    record.flexible    = item[:flexible] || false
    record.is_public   = item.fetch(:is_public, true)
    record.volunteer_capacity = item[:volunteer_capacity]
    record.created_by  = nil
    record.save!
  end
end

# Remove slugs that existed in earlier schedule versions (including the prior
# Blue Ridge Ruby fork) but are no longer part of the canonical schedule.
# Cascades to plan_items via dependent: :destroy.
obsolete_slugs = %w[
  sat-morning sat-afternoon sat-evening sat-embassy-am sat-embassy-pm
  wed-meetup thu-registration thu-welcome thu-talk-1 thu-break-1 thu-talk-2
  thu-break-2 thu-talk-3 thu-lunch thu-mystery thu-break-3 thu-talk-4
  thu-break-4 thu-talk-5 thu-closing thu-dinner thu-roundtable fri-coffee
  fri-welcome fri-talk-1 fri-break-1 fri-talk-2 fri-break-2 fri-talk-3
  fri-lunch fri-lightning fri-break-3 fri-talk-4 fri-break-4 fri-talk-5
  fri-closing fri-dinner fri-afterparty sat-hackday sat-dinner
]
ScheduleItem.where(slug: obsolete_slugs).destroy_all
