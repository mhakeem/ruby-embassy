# Seeds are idempotent — safe to run repeatedly, including in production.

# 1. Admin users. find_or_initialize_by + explicit save! ensures an existing
#    row gets updated to role: :admin if it already exists in prod but with
#    a different role.
admin_users = [
  { email: "katyasarmientodev@gmail.com", first_name: "Katya", last_name: "Sarmiento" },
  { email: "mazhak+dev@msn.com",          first_name: "Mazin", last_name: "Hakeem (Dev)"    },
  { email: "spike@rockymtnruby.dev",      first_name: "Spike", last_name: "Ilacqua"          }
]

admin_users.each do |attrs|
  user = User.find_or_initialize_by(email: attrs[:email])
  user.first_name ||= attrs[:first_name]
  user.last_name  ||= attrs[:last_name]
  user.role = :admin
  user.save!
end

# 2. Schedule items — extracted to a standalone file so it can be run
#    independently in production to re-sync the schedule without re-running
#    admin-user seeds:
#       rails runner db/seeds/schedule.rb
load Rails.root.join("db/seeds/schedule.rb").to_s

# 3. Embassy Question Bank + Notary Pool. Loaded from the curated source
#    file; idempotent upsert by external_id. Admins can edit/archive/add
#    questions afterward at /admin/embassy_questions without affecting
#    submitted application data.
require Rails.root.join("db/seeds/embassy_questions").to_s
EmbassyQuestionsSeed.import!
