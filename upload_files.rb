# -*- encoding : utf-8 -*-
module UploadFiles

  def to_jq_upload
    {
      "id" => read_attribute(:id),
      "name" => read_attribute(:upload_file_name),
      "size" => read_attribute(:upload_file_size),
      "url" => upload.url(:original),
      "thumbnail_url" => (upload_content_type.index("image/") ? upload.url(:thumbnail) : get_uploaded_file_icon(read_attribute(:upload_file_name))),
      "delete_url" => upload_path(self, upload_model: self.class.to_s, master_id:self.master),
      "delete_type" => "DELETE" 
    }

  end

  private

  def allow_only_images
    if !(upload.content_type =~ %r{^(image|(x-)?application)/(x-png|pjpeg|jpeg|jpg|png|gif)$})
      return false 
    end
  end 

  def get_uploaded_file_icon(file_name)
    file = "/plugins/icons/files/#{file_name.split(".").pop.downcase}.png"
    FileTest.exists?("#{Rails.root}/public/#{file}") ? file : "/plugins/icons/attachment.png"
  end

end