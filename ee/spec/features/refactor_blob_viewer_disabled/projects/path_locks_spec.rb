# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Path Locks', :js do
  include Spec::Support::Helpers::ModalHelpers

  let(:user) { create(:user) }
  let(:project) { create(:project, :repository, namespace: user.namespace) }
  let(:tree_path) { project_tree_path(project, project.repository.root_ref) }

  before do
    allow(project).to receive(:feature_available?).with(:file_locks) { true }
    stub_feature_flags(refactor_blob_viewer: false)

    project.add_maintainer(user)
    sign_in(user)

    visit tree_path

    wait_for_requests
  end

  it 'locking folders' do
    within '.tree-content-holder' do
      click_link "encoding"
    end

    find('.js-path-lock').click
    wait_for_requests

    accept_gl_confirm('Are you sure you want to lock this directory?')

    expect(page).to have_link('Unlock')
  end

  it 'locking files' do
    page_tree = find('.tree-content-holder')

    within page_tree do
      click_link "VERSION"
    end

    within '.file-actions' do
      click_link "Lock"
    end

    accept_gl_confirm('Are you sure you want to lock VERSION?')

    expect(page).to have_link('Unlock')
  end

  it 'unlocking files' do
    page_tree = find('.tree-content-holder')

    within page_tree do
      click_link "VERSION"
    end

    within '.file-actions' do
      click_link "Lock"
    end

    accept_gl_confirm('Are you sure you want to lock VERSION?')

    expect(page).to have_link('Lock')
  end

  it 'managing of lock list' do
    create :path_lock, path: 'encoding', user: user, project: project

    click_link "Locked Files"

    within '.locks' do
      expect(page).to have_content('encoding')

      click_link "Unlock"
    end

    accept_gl_confirm('Are you sure you want to unlock encoding?')

    within '.locks' do
      expect(page).not_to have_content('encoding')
    end
  end
end
