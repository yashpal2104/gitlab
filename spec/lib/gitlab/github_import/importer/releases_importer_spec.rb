# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::GithubImport::Importer::ReleasesImporter, feature_category: :importer do
  let(:project) { create(:project) }
  let(:client) { double(:client) }
  let(:importer) { described_class.new(project, client) }
  let(:github_release_name) { 'Initial Release' }
  let(:created_at) { Time.new(2017, 1, 1, 12, 00) }
  let(:released_at) { Time.new(2017, 1, 1, 12, 00) }
  let(:author) do
    {
      login: 'User A',
      id: 1
    }
  end

  let(:github_release) do
    {
      tag_name: '1.0',
      name: github_release_name,
      body: 'This is my release',
      created_at: created_at,
      published_at: released_at,
      author: author
    }
  end

  def stub_email_for_github_username(user_name = 'User A', user_email = 'user@example.com')
    allow_next_instance_of(Gitlab::GithubImport::UserFinder) do |instance|
      allow(instance).to receive(:email_for_github_username)
        .with(user_name).and_return(user_email)
    end
  end

  describe '#execute' do
    before do
      stub_email_for_github_username
    end

    it 'imports the releases in bulk' do
      release_hash = {
        tag_name: '1.0',
        description: 'This is my release',
        created_at: created_at,
        updated_at: created_at,
        released_at: released_at
      }

      expect(importer).to receive(:build_releases).and_return([[release_hash], []])
      expect(importer).to receive(:bulk_insert).with([release_hash])

      importer.execute
    end

    it 'imports draft releases' do
      release_double = {
        name: 'Test',
        body: 'This is description',
        tag_name: '1.0',
        description: 'This is my release',
        created_at: created_at,
        updated_at: created_at,
        published_at: nil,
        author: author
      }

      expect(importer).to receive(:each_release).and_return([release_double])

      expect { importer.execute }.to change { Release.count }.by(1)
    end

    it 'is idempotent' do
      allow(importer).to receive(:each_release).and_return([github_release])
      expect { importer.execute }.to change { Release.count }.by(1)
      expect { importer.execute }.to change { Release.count }.by(0) # Idempotency check
    end
  end

  describe '#build_releases' do
    before do
      stub_email_for_github_username
    end

    it 'returns an Array containing release rows' do
      expect(importer).to receive(:each_release).and_return([github_release])

      rows, errors = importer.build_releases

      expect(rows.length).to eq(1)
      expect(rows[0][:tag]).to eq('1.0')
      expect(errors).to be_empty
    end

    it 'does not create releases that already exist' do
      create(:release, project: project, tag: '1.0', description: '1.0')

      expect(importer).to receive(:each_release).and_return([github_release])

      rows, errors = importer.build_releases

      expect(rows).to be_empty
      expect(errors).to be_empty
    end

    it 'uses a default release description if none is provided' do
      github_release[:body] = nil
      expect(importer).to receive(:each_release).and_return([github_release])

      release, _ = importer.build_releases.first

      expect(release[:description]).to eq('Release for tag 1.0')
    end

    it 'does not create releases that have a NULL tag' do
      null_tag_release = {
        name: 'NULL Test',
        tag_name: nil
      }

      expect(importer).to receive(:each_release).and_return([null_tag_release])

      rows, errors = importer.build_releases

      expect(rows).to be_empty
      expect(errors).to be_empty
    end

    it 'does not create duplicate release tags' do
      expect(importer).to receive(:each_release).and_return([github_release, github_release])

      releases, _ = importer.build_releases
      expect(releases.length).to eq(1)
      expect(releases[0][:description]).to eq('This is my release')
    end

    it 'does not create invalid release' do
      github_release[:body] = SecureRandom.alphanumeric(Gitlab::Database::MAX_TEXT_SIZE_LIMIT + 1)

      expect(importer).to receive(:each_release).and_return([github_release])

      releases, errors = importer.build_releases

      expect(releases).to be_empty
      expect(errors.length).to eq(1)
      expect(errors[0].full_messages).to match_array(['Description is too long (maximum is 1000000 characters)'])
    end
  end

  describe '#build_attributes' do
    let(:release_hash) { importer.build_attributes(github_release) }

    context 'the returned Hash' do
      before do
        stub_email_for_github_username
      end

      it 'returns the attributes of the release as a Hash' do
        expect(release_hash).to be_an_instance_of(Hash)
      end

      it 'includes the tag name' do
        expect(release_hash[:tag]).to eq('1.0')
      end

      it 'includes the release description' do
        expect(release_hash[:description]).to eq('This is my release')
      end

      it 'includes the project ID' do
        expect(release_hash[:project_id]).to eq(project.id)
      end

      it 'includes the created timestamp' do
        expect(release_hash[:created_at]).to eq(created_at)
      end

      it 'includes the updated timestamp' do
        expect(release_hash[:updated_at]).to eq(created_at)
      end

      it 'includes the release name' do
        expect(release_hash[:name]).to eq(github_release_name)
      end
    end

    context 'author_id attribute' do
      it 'returns the Gitlab user_id when Github release author is found' do
        # Stub user email which matches a Gitlab user.
        stub_email_for_github_username('User A', project.users.first.email)

        # Disable cache read as the redis cache key can be set by other specs.
        # https://gitlab.com/gitlab-org/gitlab/-/blob/88bffda004e0aca9c4b9f2de86bdbcc0b49f2bc7/lib/gitlab/github_import/user_finder.rb#L75
        # Above line can return different user when read from cache.
        allow(Gitlab::Cache::Import::Caching).to receive(:read).and_return(nil)

        expect(release_hash[:author_id]).to eq(project.users.first.id)
      end

      it 'returns ghost user when author is empty in Github release' do
        github_release[:author] = nil

        expect(release_hash[:author_id]).to eq(Gitlab::GithubImport.ghost_user_id)
      end

      context 'when Github author is not found in Gitlab' do
        let(:author) { { login: 'octocat', id: 1 } }

        before do
          # Stub user email which does not match a Gitlab user.
          stub_email_for_github_username('octocat', 'octocat@example.com')
        end

        it 'returns project creator as author' do
          expect(release_hash[:author_id]).to eq(project.creator_id)
        end
      end
    end
  end

  describe '#each_release' do
    let(:github_release) { double(:github_release) }

    before do
      allow(project).to receive(:import_source).and_return('foo/bar')

      allow(client)
        .to receive(:releases)
        .with('foo/bar')
        .and_return([github_release].to_enum)
    end

    it 'returns an Enumerator' do
      expect(importer.each_release).to be_an_instance_of(Enumerator)
    end

    it 'yields every release to the Enumerator' do
      expect(importer.each_release.next).to eq(github_release)
    end
  end

  describe '#description_for' do
    it 'returns the description when present' do
      expect(importer.description_for(github_release)).to eq(github_release[:body])
    end

    it 'returns a generated description when one is not present' do
      github_release[:body] = nil

      expect(importer.description_for(github_release)).to eq('Release for tag 1.0')
    end
  end
end
