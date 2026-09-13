require "test_helper"

class PlanControllerTest < ActionDispatch::IntegrationTest
  test "index hides passed items from the user's plan by default" do
    alice = users(:attendee_one)
    upcoming = ScheduleItem.create!(day: "mon", title: "Alice-upcoming", kind: :activity,
                                    is_public: true, time_label: "10:00 AM", sort_time: 1000)
    finished = ScheduleItem.create!(day: "mon", title: "Alice-done", kind: :activity,
                                    is_public: true, time_label: "11:00 AM", sort_time: 1100, passed: true)
    alice.plan_items.create!(schedule_item: upcoming)
    alice.plan_items.create!(schedule_item: finished)

    sign_in_as alice
    get plan_path
    assert_match upcoming.title, response.body
    assert_no_match finished.title, response.body
  end

  test "index hides a day section when all the user's plan items on that day are passed" do
    alice = users(:attendee_one)
    sun_done = ScheduleItem.create!(day: "sun", title: "Sun-only-passed", kind: :activity,
                                    is_public: true, time_label: "11:00 AM", sort_time: 1100, passed: true)
    mon_upcoming = ScheduleItem.create!(day: "mon", title: "Mon-still-here", kind: :activity,
                                        is_public: true, time_label: "10:00 AM", sort_time: 1000)
    alice.plan_items.create!(schedule_item: sun_done)
    alice.plan_items.create!(schedule_item: mon_upcoming)

    sign_in_as alice
    get plan_path
    assert_no_match "Sunday", response.body
    assert_match "Monday", response.body

    get plan_path, params: { show_past: "1" }
    assert_match "Sunday", response.body
    assert_match "Monday", response.body
  end

  test "index shows passed items when show_past=1" do
    alice = users(:attendee_one)
    finished = ScheduleItem.create!(day: "mon", title: "Alice-done-visible", kind: :activity,
                                    is_public: true, time_label: "11:00 AM", sort_time: 1100, passed: true)
    alice.plan_items.create!(schedule_item: finished)

    sign_in_as alice
    get plan_path, params: { show_past: "1" }
    assert_match finished.title, response.body
  end
end
