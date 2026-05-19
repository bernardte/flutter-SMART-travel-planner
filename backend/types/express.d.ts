import { IUser } from "../models/user.model";
//!  follows a specific TypeScript convention used to provide 
//! type information for the Express framework. 
declare global {
    namespace Express {
        interface Request {
            user?: IUser | null
        }
    }
}

export {};