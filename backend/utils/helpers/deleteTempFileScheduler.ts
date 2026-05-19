import cron from "node-cron";
import fs from "fs";
import path from "path";

//* cwd(): current working directory
const tempFileDir = path.join(process.cwd(), "temp");

if (!fs.existsSync(path.join(process.cwd(), "temp"))) {
  fs.mkdirSync(path.join(process.cwd(), "temp"));
}

const deleteTempfileScheduler = cron.schedule("10 * * * * *", () => {
  if (fs.existsSync(tempFileDir)) {
    fs.readdir(tempFileDir, (error, files) => {
      if (error) {
        console.log("Error reading temp folder in deleteTempfileScheduler: ");
        return;
      }

      for (const file of files) {
        const filePath = path.join(tempFileDir, file);
        fs.unlink(filePath, (error) => {
          if (error) {
            console.error(`Failed to delete file ${file}: ${error}`);
          }

          console.log(`Deleted file: ${file}`);
        });
      }
    });
  }
});

export default deleteTempfileScheduler;
