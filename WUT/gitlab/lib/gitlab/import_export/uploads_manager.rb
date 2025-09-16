# frozen_string_literal: true

module Gitlab
  module ImportExport
    class UploadsManager
      include Gitlab::ImportExport::CommandLineUtil
      include ::Import::Framework::ProgressTracking

      UPLOADS_BATCH_SIZE = 100

      attr_reader :project

      def initialize(project:, shared:, relative_export_path: 'uploads')
        @project = project
        @shared = shared
        @relative_export_path = relative_export_path
      end

      def save
        copy_project_uploads

        true
      rescue StandardError => e
        @shared.error(e)
        false
      end

      def restore
        Dir["#{uploads_export_path}/**/*"].each do |upload|
          next if File.directory?(upload)

          with_progress_tracking(**progress_tracking_options(upload)) do
            add_upload(upload)
          end
        end

        true
      rescue StandardError => e
        @shared.error(e)
        false
      end

      private

      def add_upload(upload)
        uploader_context = FileUploader.extract_dynamic_path(upload).named_captures.symbolize_keys

        UploadService.new(@project, File.open(upload, 'r'), FileUploader, **uploader_context).execute.to_h
      end

      def copy_project_uploads
        each_uploader do |uploader|
          next unless uploader.file

          if uploader.upload.local?
            next unless uploader.upload.exist?

            copy_files(uploader.absolute_path, File.join(uploads_export_path, uploader.upload.path))
          else
            download_and_copy(uploader)
          end
        end
      end

      def uploads_export_path
        @uploads_export_path ||= File.join(@shared.export_path, @relative_export_path)
      end

      def each_uploader
        avatar_path = @project.avatar&.upload&.path

        if @relative_export_path == 'avatar'
          yield(@project.avatar)
        else
          project_uploads_except_avatar(avatar_path).find_each(batch_size: UPLOADS_BATCH_SIZE) do |upload|
            yield(upload.retrieve_uploader)
          end
        end
      end

      def project_uploads_except_avatar(avatar_path)
        return @project.uploads unless avatar_path

        @project.uploads.where.not(path: avatar_path)
      end

      def download_and_copy(upload)
        secret = upload.try(:secret) || ''
        upload_path = File.join(uploads_export_path, secret, upload.filename)

        mkdir_p(File.join(uploads_export_path, secret))

        download_or_copy_upload(upload, upload_path)
      rescue StandardError => e
        # Do not fail entire project export if something goes wrong during file download
        # (e.g. downloaded file has filename that exceeds 255 characters).
        # Ignore raised exception, skip such upload, log the error and keep going with the export instead.
        Gitlab::ErrorTracking.log_exception(e, project_id: @project.id)
      end

      def progress_tracking_options(upload_path)
        { scope: { project_id: project.id }, data: filename_with_object_id(upload_path) }
      end

      # Returns filename and the dir name the upload is in
      # e.g. 72a497a02fe3ee09edae2ed06d390038/image.png
      def filename_with_object_id(upload_path)
        upload_path.split('/').last(2).join('/')
      end
    end
  end
end
