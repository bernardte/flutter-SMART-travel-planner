import cloudinary from "../../config/cloudinary.js";

export const deleteFromCloudinary = async (publicId: string) => {
  try {
    const result = await cloudinary.uploader.destroy(publicId);

    console.log("Cloudinary delete result:", result);

    return result;
  } catch (error) {
    console.log("Cloudinary delete error", error);
  }
};