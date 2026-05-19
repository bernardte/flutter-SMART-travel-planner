import cloudinary from "../../config/cloudinary.js";

/**
 * Upload single file buffer to Cloudinary
 */

interface CloudinaryUploadResult {
  url: string;
  public_id: string;
}

export const uploadToCloudinary = (
  fileBuffer: Buffer,
  folder: string = "uploads",
  uploadPreset?: string,
): Promise<CloudinaryUploadResult> => {
  return new Promise((resolve, reject) => {
    const options: any = {
      folder,
    };

    //  only add if exists
    if (uploadPreset) {
      options.upload_preset = uploadPreset;
    }

    const stream = cloudinary.uploader.upload_stream(
      options,
      (error, result) => {
        if (error) return reject(error);
        if (!result) return reject("Upload failed");

        resolve({ url: result.secure_url, public_id: result.public_id });
      },
    );

    stream.end(fileBuffer);
  });
};
