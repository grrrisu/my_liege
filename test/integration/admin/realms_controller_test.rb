require 'test_helper'

class Admin::RealmsControllerTest < ActionDispatch::IntegrationTest

  test "show realm" do
    visit admin_realms_path
    page.assert_text('Realm Test')

    assert page.find('.ci-idle', text: '1')
    assert page.find('.ci-pending', text: '1')
    assert page.find('.ci-queued', text: '1')
    assert page.find('.ci-performing', text: '1')

    Sidekiq::Testing.inline! do
      SimLoopJob.new.sim_next_objects
    end

    visit admin_realms_path
    assert page.find('.ci-idle', text: '2')
    assert page.find('.ci-pending', text: '0')
    assert page.find('.ci-queued', text: '1')
    assert page.find('.ci-performing', text: '1')
  end

end
