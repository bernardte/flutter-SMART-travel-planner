import mongoose from "mongoose";

export function mongoDBObjectIDConverter(_id: string){
    return new mongoose.Types.ObjectId(_id);
}