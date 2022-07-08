# frozen_string_literal: true
require "spec_helper"

RSpec.describe Pajamas::AvatarComponent, type: :component do
  let_it_be(:user) { create(:user) }
  let_it_be(:project) { create(:project) }
  let_it_be(:group) { create(:group) }

  let(:options) { {} }

  before do
    render_inline(described_class.new(record, **options))
  end

  describe "avatar shape" do
    context "given a User" do
      let(:record) { user }

      it "has a circle shape" do
        expect(page).to have_css ".gl-avatar.gl-avatar-circle"
      end
    end

    context "given a Project" do
      let(:record) { project }

      it "has default shape (rect)" do
        expect(page).to have_css ".gl-avatar"
        expect(page).not_to have_css ".gl-avatar-circle"
      end
    end

    context "given a Group" do
      let(:record) { group }

      it "has default shape (rect)" do
        expect(page).to have_css ".gl-avatar"
        expect(page).not_to have_css ".gl-avatar-circle"
      end
    end
  end

  describe "avatar image" do
    context "when it has an uploaded image" do
      let(:record) { project }

      before do
        allow(record).to receive(:avatar_url).and_return "/example.png"
        render_inline(described_class.new(record, **options))
      end

      it "uses the avatar_url as image src" do
        expect(page).to have_css "img.gl-avatar[src='/example.png?width=64']"
      end

      it "uses lazy loading" do
        expect(page).to have_css "img.gl-avatar[loading='lazy']"
      end

      context "with size option" do
        let(:options) { { size: 16 } }

        it "adds the size as param to image src" do
          expect(page).to have_css "img.gl-avatar[src='/example.png?width=16']"
        end
      end
    end

    context "when a project or group has no uploaded image" do
      let(:record) { project }

      it "uses an identicon with the record's initial" do
        expect(page).to have_css "div.gl-avatar.gl-avatar-identicon", text: record.name[0].upcase
      end
    end

    context "when a user has no uploaded image" do
      let(:record) { user }

      it "uses a gravatar" do
        expect(rendered_component).to match /gravatar\.com/
      end
    end
  end

  describe "options" do
    let(:record) { user }

    describe "alt" do
      context "with a value" do
        let(:options) { { alt: "Profile picture" } }

        it "uses given value as alt text" do
          expect(page).to have_css ".gl-avatar[alt='Profile picture']"
        end
      end

      context "without a value" do
        it "uses the record's name as alt text" do
          expect(page).to have_css ".gl-avatar[alt='#{record.name}']"
        end
      end
    end

    describe "class" do
      let(:options) { { class: 'gl-m-4' } }

      it 'has the correct custom class' do
        expect(page).to have_css '.gl-avatar.gl-m-4'
      end
    end

    describe "size" do
      let(:options) { { size: 96 } }

      it 'has the correct size class' do
        expect(page).to have_css '.gl-avatar.gl-avatar-s96'
      end
    end
  end
end
