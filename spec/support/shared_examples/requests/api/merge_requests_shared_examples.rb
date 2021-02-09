# frozen_string_literal: true

RSpec.shared_examples 'rejects user from accessing merge request info' do
  let(:project) { create(:project, :private) }
  let(:merge_request) do
    create(:merge_request,
      author: user,
      source_project: project,
      target_project: project
    )
  end

  before do
    project.add_guest(user)
  end

  it 'returns a 404 error' do
    get api(url, user)

    expect(response).to have_gitlab_http_status(:not_found)
    expect(json_response['message']).to eq('404 Merge Request Not Found')
  end
end
