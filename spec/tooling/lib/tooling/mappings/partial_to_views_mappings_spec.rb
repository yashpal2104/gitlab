# frozen_string_literal: true

require 'tempfile'
require 'fileutils'
require_relative '../../../../../tooling/lib/tooling/mappings/partial_to_views_mappings'

RSpec.describe Tooling::Mappings::PartialToViewsMappings, feature_category: :tooling do
  attr_accessor :view_base_folder, :changes_file, :output_file

  let(:instance)             { described_class.new(changes_file, output_file, view_base_folder: view_base_folder) }
  let(:changes_file_content) { "changed_file1 changed_file2" }
  let(:output_file_content)  { "previously_added_view.html.haml" }

  around do |example|
    self.changes_file        = Tempfile.new('changes')
    self.output_file         = Tempfile.new('output_file')

    # See https://ruby-doc.org/stdlib-1.9.3/libdoc/tempfile/rdoc/
    #     Tempfile.html#class-Tempfile-label-Explicit+close
    begin
      Dir.mktmpdir do |tmp_views_base_folder|
        self.view_base_folder = tmp_views_base_folder
        example.run
      end
    ensure
      changes_file.close
      output_file.close
      changes_file.unlink
      output_file.unlink
    end
  end

  before do
    # We write into the temp files initially, to check how the code modified those files
    File.write(changes_file, changes_file_content)
    File.write(output_file, output_file_content)
  end

  describe '#execute' do
    subject { instance.execute }

    let(:changed_files)        { ["#{view_base_folder}/my_view.html.haml"] }
    let(:changes_file_content) { changed_files.join(" ") }

    before do
      # We create all of the changed_files, so that they are part of the filtered files
      changed_files.each { |changed_file| FileUtils.touch(changed_file) }
    end

    it 'does not modify the content of the input file' do
      expect { subject }.not_to change { File.read(changes_file) }
    end

    context 'when no partials were modified' do
      it 'does not change the output file' do
        expect { subject }.not_to change { File.read(output_file) }
      end
    end

    context 'when some partials were modified' do
      let(:changed_files) do
        [
          "#{view_base_folder}/my_view.html.haml",
          "#{view_base_folder}/_my_partial.html.haml",
          "#{view_base_folder}/_my_other_partial.html.haml"
        ]
      end

      before do
        # We create a red-herring partial to have a more convincing test suite
        FileUtils.touch("#{view_base_folder}/_another_partial.html.haml")
      end

      context 'when the partials are not included in any views' do
        before do
          File.write("#{view_base_folder}/my_view.html.haml", "render 'another_partial'")
        end

        it 'does not change the output file' do
          expect { subject }.not_to change { File.read(output_file) }
        end
      end

      context 'when the partials are included in views' do
        before do
          File.write("#{view_base_folder}/my_view.html.haml", "render 'my_partial'")
        end

        it 'writes the view including the partial to the output' do
          expect { subject }.to change { File.read(output_file) }
                            .from(output_file_content)
                            .to(output_file_content + " #{view_base_folder}/my_view.html.haml")
        end
      end
    end
  end

  describe '#filter_files' do
    subject { instance.filter_files }

    let(:changes_file_content) { file_path }

    context 'when the file does not exist on disk' do
      let(:file_path) { "#{view_base_folder}/_index.html.erb" }

      it 'returns an empty array' do
        expect(subject).to be_empty
      end
    end

    context 'when the file exists on disk' do
      before do
        File.write(file_path, "I am a partial!")
      end

      context 'when the file is not in the view base folders' do
        let(:file_path) { "/tmp/_index.html.haml" }

        it 'returns an empty array' do
          expect(subject).to be_empty
        end
      end

      context 'when the filename does not start with an underscore' do
        let(:file_path) { "#{view_base_folder}/index.html.haml" }

        it 'returns an empty array' do
          expect(subject).to be_empty
        end
      end

      context 'when the filename does not have the correct extension' do
        let(:file_path) { "#{view_base_folder}/_index.html.erb" }

        it 'returns an empty array' do
          expect(subject).to be_empty
        end
      end

      context 'when the file is a partial' do
        let(:file_path) { "#{view_base_folder}/_index.html.haml" }

        it 'returns the file' do
          expect(subject).to match_array(file_path)
        end
      end
    end
  end

  describe '#extract_partial_keyword' do
    subject { instance.extract_partial_keyword('ee/app/views/shared/_new_project_item_vue_select.html.haml') }

    it 'returns the correct partial keyword' do
      expect(subject).to eq('new_project_item_vue_select')
    end
  end

  describe '#view_includes_modified_partial?' do
    subject { instance.view_includes_modified_partial?(view_file, included_partial_name) }

    context 'when the included partial name is relative to the view file' do
      let(:view_file)             { "#{view_base_folder}/components/my_view.html.haml" }
      let(:included_partial_name) { 'subfolder/relative_partial' }

      before do
        FileUtils.mkdir_p("#{view_base_folder}/components/subfolder")
        File.write(changes_file_content, "I am a partial!")
      end

      context 'when the partial is not part of the changed files' do
        let(:changes_file_content) { "#{view_base_folder}/components/subfolder/_not_the_partial.html.haml" }

        it 'returns false' do
          expect(subject).to be_falsey
        end
      end

      context 'when the partial is part of the changed files' do
        let(:changes_file_content) { "#{view_base_folder}/components/subfolder/_relative_partial.html.haml" }

        it 'returns true' do
          expect(subject).to be_truthy
        end
      end
    end

    context 'when the included partial name is relative to the base views folder' do
      let(:view_file)             { "#{view_base_folder}/components/my_view.html.haml" }
      let(:included_partial_name) { 'shared/absolute_partial' }

      before do
        FileUtils.mkdir_p("#{view_base_folder}/components")
        FileUtils.mkdir_p("#{view_base_folder}/shared")
        File.write(changes_file_content, "I am a partial!")
      end

      context 'when the partial is not part of the changed files' do
        let(:changes_file_content) { "#{view_base_folder}/shared/not_the_partial" }

        it 'returns false' do
          expect(subject).to be_falsey
        end
      end

      context 'when the partial is part of the changed files' do
        let(:changes_file_content) { "#{view_base_folder}/shared/_absolute_partial.html.haml" }

        it 'returns true' do
          expect(subject).to be_truthy
        end
      end
    end
  end

  describe '#reconstruct_partial_filename' do
    subject { instance.reconstruct_partial_filename(partial_name) }

    context 'when the partial does not contain a path' do
      let(:partial_name) { 'sidebar' }

      it 'returns the correct filename' do
        expect(subject).to eq('_sidebar.html.haml')
      end
    end

    context 'when the partial contains a path' do
      let(:partial_name) { 'shared/components/sidebar' }

      it 'returns the correct filename' do
        expect(subject).to eq('shared/components/_sidebar.html.haml')
      end
    end
  end

  describe '#find_pattern_in_file' do
    let(:subject) { instance.find_pattern_in_file(file.path, /pattern/) }
    let(:file)    { Tempfile.new('find_pattern_in_file') }

    before do
      file.write(file_content)
      file.close
    end

    context 'when the file contains the pattern' do
      let(:file_content) do
        <<~FILE
          Beginning of file

          pattern
          pattern
          pattern

          End of file
        FILE
      end

      it 'returns the pattern once' do
        expect(subject).to match_array(%w[pattern])
      end
    end

    context 'when the file does not contain the pattern' do
      let(:file_content) do
        <<~FILE
          Beginning of file
          End of file
        FILE
      end

      it 'returns an empty array' do
        expect(subject).to match_array([])
      end
    end
  end
end
