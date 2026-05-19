# Backend Developer Guide (Node.js + Express + TypeScript)

Welcome to the backend project. This guide is written for beginners so you can quickly understand how to run the project, folder structure, and how the MVC pattern works.

---

# 📌 Tech Stack

* Node.js
* Express.js
* TypeScript
* dotenv
* @t3-oss/env-core
* REST API

---

# 🚀 How to Run the Project

## 1. Install Dependencies

```bash
npm install
```

---

## 2. Create `.env`

Create a `.env` file in the root backend folder.

Example:

```env
PORT=5000
FRONTEND_URL=http://localhost:3000
JWT_SECRET=your_secret_key
```

---

## 3. Start Development Server

```bash
npm run dev
```

Expected output:

```bash
Server is running on port 5000
```

---

## 4. Production Build (Optional)

```bash
npm run build
npm start
```

---

# 📁 Project Folder Structure

```text
backend/
│── src/
│   │── config/
│   │── controllers/
│   │── middleware/
│   │── models/
│   │── routes/
│   │── services/
│   │── utils/
│   │── app.ts
│   └── server.ts
│── .gitignore
│── .env
│── package.json
│── tsconfig.json
│── BACKEND_GUIDE.md
```

---

# 🧠 MVC Pattern Explanation

MVC = Model + View + Controller

Since backend has no UI pages, "View" usually means JSON API response.

---

# 📦 1. Models (`src/models/`)

Responsible for database structure and data operations.

Examples:

* User model
* Trip model
* Booking model

Example:

```ts
User.ts
Trip.ts
```

Use models when:

* Saving data
* Reading data
* Updating data
* Deleting data

---

# 🎮 2. Controllers (`src/controllers/`)

Responsible for handling request and response.

Example:

```ts
authController.ts
tripController.ts
adminController.ts
```

What controllers do:

* Receive request from route
* Validate input
* Call service/model
* Return JSON response

Example:

```ts
loginUser(req, res)
createTrip(req, res)
deleteTrip(req, res)
```

---

# 🛣️ 3. Routes (`src/routes/`)

Responsible for API endpoints.

Example:

```ts
authRoutes.ts
tripRoutes.ts
adminRoutes.ts
```

Example:

```ts
router.post("/login", loginUser);
router.post("/trip", createTrip);
router.get("/users", getAllUsers);
```

---

# 🧩 4. Services (`src/services/`)

Responsible for business logic.

Examples:

* Generate JWT token
* Calculate trip budget
* Call third-party APIs
* Complex database logic

Example:

```ts
authService.ts
weatherService.ts
tripService.ts
```

---

# 🛡️ 5. Middleware (`src/middleware/`)

Runs before controller.

Examples:

* Verify JWT token
* Check admin role
* Error handling
* Rate limiting

Example:

```ts
authMiddleware.ts
roleMiddleware.ts
errorMiddleware.ts
```

---

# ⚙️ 6. Config (`src/config/`)

Store app settings.

Examples:

* Environment variables - Present env file values not missing (env.ts)
* Database connection
* Cloud storage config

Example:

```ts
env.ts
db.ts
```

---

# 🧰 7. Utils (`src/utils/`)

Reusable helper functions.

Examples:

* Format date
* Hash password
* Generate random code

Example:

```ts
hash.ts
response.ts
```

---

# 🧱 app.ts vs server.ts

## `app.ts`

Contains:
* express app
* middleware
* routes

Example:
```ts
const app = express();
app.use(cors());
app.use("/api/auth", authRoutes);
```

---

## `server.ts`

Responsible for starting server.

Example:

```ts
app.listen(PORT, () => {
  console.log(`Server running on ${PORT}`);
});
```

---

# 🌐 Example API Flow

```text
Frontend Request
      ↓
Route
      ↓
Middleware
      ↓
Controller
      ↓
Service
      ↓
Model / Database
      ↓
JSON Response
```

---

# 🔐 Authentication Example

## Login Flow

```text
POST /api/auth/login
```

Process:

1. User sends email + password
2. Controller validates request
3. Service checks password
4. JWT token generated
5. Token returned in cookie / response

---

# 👑 RBAC Example

Roles:

* user
* admin

Example:

```text
GET /api/admin/users
```

Only admin can access.

---

# 🧪 Testing API

Use:

* Postman
* Thunder Client
* Insomnia
* HTTPie

Example:

```text
GET http://localhost:5000/api/trips
POST http://localhost:5000/api/auth/login
```

---

# 📌 Rules for New Developers

## When adding new feature:

Example: Add Review System

Create:

```text
models/reviewModel.ts
controllers/reviewController.ts
routes/reviewRoutes.ts
services/reviewService.ts
```

Then register route in `app.ts`

---

# 🧼 Clean Code Rules

* Keep controller thin
* Put logic in service
* Use async/await
* Handle errors properly
* Use meaningful names
* One responsibility per file

---

# ❌ Common Mistakes

## 1. Put everything in server.ts

Wrong ❌

## 2. Put database query inside route file

Wrong ❌

## 3. Hardcode secret key

Wrong ❌

Use `.env`

---

# ✅ Good Example

```text
routes → controller → service → model
```

---

# 📞 If Server Cannot Run

Check:

```bash
npm install
npm run dev
```

Check:

* `.env` exists
* PORT available
* Correct import paths
* No TypeScript errors

---

# 🎯 Final Advice

For beginners:

1. Understand routes first
2. Then controller
3. Then database model
4. Then middleware
5. Then services

Do not try understand everything at once.

---

# 🚀 Happy Coding

Build clean, secure, and scalable backend APIs.
