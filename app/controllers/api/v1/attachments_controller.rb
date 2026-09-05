module Api
  module V1
    # Not tied to a specific page — for API clients (docs generators,
    # Copilot/Claude skills, etc.) that need to embed an image or file
    # inline in a Page's content the same way Trix does when you drag one
    # into the editor. Upload here first, then splice the returned `html`
    # into the `content` you send to POST/PATCH /api/v1/pages.
    class AttachmentsController < Api::BaseController
      def create
        unless current_user&.admin? || current_user&.member?
          return render json: { error: "Forbidden" }, status: :forbidden
        end

        file = params[:file]
        unless file.respond_to?(:read)
          return render json: { error: "file is required (multipart/form-data)." }, status: :unprocessable_entity
        end

        blob = ActiveStorage::Blob.create_and_upload!(
          io: file,
          filename: file.original_filename,
          content_type: file.content_type
        )

        render json: {
          signed_id: blob.signed_id,
          filename: blob.filename.to_s,
          content_type: blob.content_type,
          byte_size: blob.byte_size,
          # The exact <action-text-attachment> tag ActionText itself
          # generates — paste this straight into a page's `content` HTML at
          # whatever point you want the image/file to appear.
          html: ActionText::Attachment.from_attachable(blob).node.to_html,
        }, status: :created
      end
    end
  end
end
