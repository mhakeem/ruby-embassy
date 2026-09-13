require "test_helper"

class SeedTest < ActiveSupport::TestCase
  self.use_transactional_tests = false

  SEEDED_ADMIN_EMAILS = %w[
    spike@rockymtnruby.dev
  ].freeze

  setup do
    User.where(email: SEEDED_ADMIN_EMAILS).destroy_all
    ScheduleItem.where.not(id: nil).destroy_all
  end

  teardown do
    User.where(email: SEEDED_ADMIN_EMAILS).destroy_all
    ScheduleItem.where.not(id: nil).destroy_all
  end

  test "seed makes spike an admin, idempotently" do
    2.times { Rails.application.load_seed }

    SEEDED_ADMIN_EMAILS.each do |email|
      assert User.find_by(email: email).admin?, "#{email} should be an admin"
    end
  end

  test "seed upserts every YAML row as a ScheduleItem, public unless flagged otherwise" do
    Rails.application.load_seed

    yaml_days = YAML.load_file(Rails.root.join("config/schedule.yml"), permitted_classes: [ Symbol ])[:days]
    yaml_items = yaml_days.sum { |d| d[:items].size }
    yaml_hidden = yaml_days.sum { |d| d[:items].count { |i| i[:is_public] == false } }

    assert_equal yaml_items, ScheduleItem.count
    assert_equal yaml_items - yaml_hidden, ScheduleItem.public_items.count
  end

  test "seed is idempotent for schedule_items" do
    Rails.application.load_seed
    count_after_first = ScheduleItem.count
    Rails.application.load_seed
    assert_equal count_after_first, ScheduleItem.count
  end

  test "seeded talks carry title (topic) and host (speaker)" do
    Rails.application.load_seed

    talk = ScheduleItem.find_by(slug: "mon-talk-1")
    assert_equal "Kevin Murphy", talk.host
    assert talk.title.start_with?("InstiLLMent"), "talk title should be the topic, not the speaker"
    assert talk.talk?
  end

  test "seeded reception items (check-in/opening/breaks/closing) are kind: reception" do
    Rails.application.load_seed

    %w[mon-checkin mon-opening mon-break-1 tue-checkin tue-opening tue-closing].each do |slug|
      item = ScheduleItem.find_by(slug: slug)
      assert_equal "reception", item.kind, "#{slug} should be kind: reception"
    end
  end

  test "seeded meal items (lunches) are kind: meal" do
    Rails.application.load_seed

    %w[mon-lunch tue-lunch].each do |slug|
      item = ScheduleItem.find_by(slug: slug)
      assert_equal "meal", item.kind, "#{slug} should be kind: meal"
    end
  end

  test "seeded community items (socials + placeholders) are kind: community" do
    Rails.application.load_seed

    %w[sun-meetup mon-happy-hour tue-hackday].each do |slug|
      item = ScheduleItem.find_by(slug: slug)
      assert_equal "community", item.kind, "#{slug} should be kind: community"
    end
  end

  test "seeded lightning talks slot is kind: lightning" do
    Rails.application.load_seed

    item = ScheduleItem.find_by(slug: "tue-lightning")
    assert_equal "lightning", item.kind
  end

  test "placeholder items (pre-conference, hack day, volunteers) are seeded but hidden from the public schedule" do
    Rails.application.load_seed

    %w[sun-meetup tue-hackday tue-volunteers].each do |slug|
      item = ScheduleItem.find_by(slug: slug)
      assert item.present?, "#{slug} should be seeded"
      assert_not item.is_public?, "#{slug} should not be public yet"
    end
  end

  test "hack day slug matches ScheduleItem::HACK_DAY_SLUG so admin Hack Projects resolves" do
    Rails.application.load_seed

    assert ScheduleItem.exists?(slug: ScheduleItem::HACK_DAY_SLUG)
  end

  test "volunteer placeholder carries a volunteer_capacity" do
    Rails.application.load_seed

    item = ScheduleItem.find_by(slug: "tue-volunteers")
    assert item.volunteer?
    assert item.volunteer_capacity.present?
  end
end
